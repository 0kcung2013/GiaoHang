import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/geo_utils.dart';
import 'location_history_queue.dart';
import 'location_ingest_config.dart';
import 'location_throttle.dart';

/// Pipeline GPS tối ưu:
///
/// ```
/// GPS sample
///   → throttle (time + distance)
///   → [ưu tiên] Edge Function → Redis GEO/latest + Redis queue
///   → fallback local:
///        UPDATE drivers (throttled)  // realtime cho khách
///        enqueue history → bulk insert driver_locations
/// ```
///
/// PostgreSQL vẫn là source of truth nghiệp vụ; history ghi batch.
class LocationIngestService {
  LocationIngestService({
    SupabaseClient? client,
    LocationThrottle? throttle,
    LocationHistoryQueue? historyQueue,
  })  : _supabase = client ?? Supabase.instance.client,
        _throttle = throttle ?? LocationThrottle(),
        _historyQueue = historyQueue ?? LocationHistoryQueue() {
    _historyQueue.start();
  }

  final SupabaseClient _supabase;
  final LocationThrottle _throttle;
  final LocationThrottle _navThrottle = LocationThrottle(
    minInterval: LocationIngestConfig.navigationMinInterval,
    minDistanceMeters: LocationIngestConfig.navigationMinDistanceMeters,
  );
  final LocationHistoryQueue _historyQueue;

  DateTime? _lastRealtimePgAt;
  String? _cachedProfileId;
  String? _cachedProfileUserId;
  bool _edgeUnavailable = false;

  /// Ingest một sample GPS.
  ///
  /// [prioritySync]: đang navigation — nới throttle + UPDATE `drivers` ~2s
  /// để map khách bám theo tài xế (không chỉ Redis).
  Future<void> ingest({
    String? driverProfileId,
    String? driverUserId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    bool force = false,
    bool prioritySync = false,
  }) async {
    if (driverProfileId == null &&
        (driverUserId == null || driverUserId.isEmpty)) {
      return;
    }

    final email = _supabase.auth.currentUser?.email;
    final adjusted = GeoUtils.applyTestDriverOffset(
      email: email,
      lat: lat,
      lng: lng,
    );

    if (!force) {
      if (prioritySync) {
        final ok = _navThrottle.shouldAccept(
          lat: adjusted.latitude,
          lng: adjusted.longitude,
        );
        if (!ok) {
          // Vẫn cố gắng chạm PG nếu đã quá interval navigation
          await _touchDriversOnly(
            driverProfileId: driverProfileId,
            driverUserId: driverUserId,
            lat: adjusted.latitude,
            lng: adjusted.longitude,
            prioritySync: true,
          );
          return;
        }
      } else if (!_throttle.shouldAccept(
        lat: adjusted.latitude,
        lng: adjusted.longitude,
      )) {
        return;
      }
    }

    // 1) Edge Redis (nếu có)
    if (LocationIngestConfig.useEdgeIngest && !_edgeUnavailable) {
      final ok = await _ingestViaEdge(
        driverProfileId: driverProfileId,
        driverUserId: driverUserId,
        lat: adjusted.latitude,
        lng: adjusted.longitude,
        heading: heading,
        speed: speed,
      );
      if (ok) {
        // Edge có thể throttle PG 8s — navigation vẫn force touch drivers.
        if (prioritySync) {
          await _touchDriversOnly(
            driverProfileId: driverProfileId,
            driverUserId: driverUserId,
            lat: adjusted.latitude,
            lng: adjusted.longitude,
            prioritySync: true,
          );
        }
        return;
      }
      _edgeUnavailable = true;
      if (kDebugMode) {
        debugPrint(
          '[LocationIngest] Edge unavailable → fallback local pipeline',
        );
      }
    }

    // 2) Fallback local
    await _ingestLocal(
      driverProfileId: driverProfileId,
      driverUserId: driverUserId,
      lat: adjusted.latitude,
      lng: adjusted.longitude,
      heading: heading,
      speed: speed,
      prioritySync: prioritySync,
    );
  }

  Future<bool> _ingestViaEdge({
    String? driverProfileId,
    String? driverUserId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        LocationIngestConfig.ingestFunctionName,
        body: {
          if (driverProfileId != null) 'driver_profile_id': driverProfileId,
          if (driverUserId != null) 'driver_user_id': driverUserId,
          'lat': lat,
          'lng': lng,
          if (heading != null) 'heading': heading,
          if (speed != null) 'speed': speed,
          'client_ts': DateTime.now().toIso8601String(),
        },
      );
      if (res.status >= 200 && res.status < 300) {
        if (kDebugMode) {
          debugPrint('[LocationIngest] edge ok status=${res.status}');
        }
        return true;
      }
      if (kDebugMode) {
        debugPrint(
          '[LocationIngest] edge status=${res.status} data=${res.data}',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationIngest] edge error: $e');
      }
      return false;
    }
  }

  Future<void> _ingestLocal({
    String? driverProfileId,
    String? driverUserId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    bool prioritySync = false,
  }) async {
    final ids = await _resolveIds(
      driverProfileId: driverProfileId,
      driverUserId: driverUserId,
    );
    if (ids == null) return;

    final now = DateTime.now();
    await _touchDriversOnly(
      driverProfileId: ids.profileId,
      driverUserId: ids.userId,
      lat: lat,
      lng: lng,
      prioritySync: prioritySync,
      resolvedProfileId: ids.profileId,
    );

    // History: bulk queue
    _historyQueue.enqueue(
      GpsHistoryPoint(
        driverProfileId: ids.profileId,
        lat: lat,
        lng: lng,
        heading: heading,
        speed: speed,
        createdAt: now,
      ),
    );
  }

  /// UPDATE `drivers` latest — nguồn Realtime/poll cho map khách.
  Future<void> _touchDriversOnly({
    String? driverProfileId,
    String? driverUserId,
    required double lat,
    required double lng,
    bool prioritySync = false,
    String? resolvedProfileId,
  }) async {
    final interval = prioritySync
        ? LocationIngestConfig.navigationRealtimePgInterval
        : LocationIngestConfig.realtimePgInterval;
    final now = DateTime.now();
    if (_lastRealtimePgAt != null &&
        now.difference(_lastRealtimePgAt!) < interval) {
      return;
    }

    String? profileId = resolvedProfileId;
    if (profileId == null) {
      final ids = await _resolveIds(
        driverProfileId: driverProfileId,
        driverUserId: driverUserId,
      );
      profileId = ids?.profileId;
    }
    if (profileId == null) return;

    try {
      await _supabase.from('drivers').update({
        'current_lat': lat,
        'current_lng': lng,
        'updated_at': now.toIso8601String(),
      }).eq('id', profileId);
      _lastRealtimePgAt = now;
      if (kDebugMode) {
        debugPrint(
          '[LocationIngest] PG drivers touch '
          '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)} '
          'priority=$prioritySync',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationIngest] PG latest update failed: $e');
      }
    }
  }

  Future<({String profileId, String userId})?> _resolveIds({
    String? driverProfileId,
    String? driverUserId,
  }) async {
    if (driverProfileId != null &&
        driverProfileId.isNotEmpty &&
        driverUserId != null &&
        driverUserId.isNotEmpty) {
      return (profileId: driverProfileId, userId: driverUserId);
    }

    if (_cachedProfileId != null &&
        _cachedProfileUserId != null &&
        ((driverProfileId != null && driverProfileId == _cachedProfileId) ||
            (driverUserId != null && driverUserId == _cachedProfileUserId))) {
      return (profileId: _cachedProfileId!, userId: _cachedProfileUserId!);
    }

    try {
      if (driverProfileId != null && driverProfileId.isNotEmpty) {
        final row = await _supabase
            .from('drivers')
            .select('id, user_id')
            .eq('id', driverProfileId)
            .maybeSingle();
        if (row == null) return null;
        _cachedProfileId = row['id']?.toString();
        _cachedProfileUserId = row['user_id']?.toString();
      } else if (driverUserId != null && driverUserId.isNotEmpty) {
        final row = await _supabase
            .from('drivers')
            .select('id, user_id')
            .eq('user_id', driverUserId)
            .maybeSingle();
        if (row == null) return null;
        _cachedProfileId = row['id']?.toString();
        _cachedProfileUserId = row['user_id']?.toString();
      }
      if (_cachedProfileId == null || _cachedProfileUserId == null) {
        return null;
      }
      return (profileId: _cachedProfileId!, userId: _cachedProfileUserId!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationIngest] resolve ids failed: $e');
      }
      return null;
    }
  }

  /// Gọi thủ công flush history (vd khi app background).
  Future<int> flushHistory() => _historyQueue.flush();

  Future<void> dispose() async {
    await _historyQueue.dispose();
  }
}
