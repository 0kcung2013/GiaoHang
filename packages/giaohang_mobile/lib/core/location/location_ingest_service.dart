import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver_location_producer_policy.dart';
import 'location_history_queue.dart';
import 'location_ingest_config.dart';
import 'location_throttle.dart';
import 'physical_gps_policy.dart';

/// Pipeline GPS tối ưu:
///
/// ```
/// GPS sample
///   → throttle (time + distance)
///   → [ưu tiên] Edge Function → Redis GEO/latest + Redis queue
///   → fallback local:
///        UPDATE drivers (throttled)  // realtime cho khách
///        enqueue history → retry Edge → R2
/// ```
///
/// PostgreSQL chỉ giữ trạng thái nghiệp vụ/vị trí mới nhất; GPS history ở R2.
class LocationIngestService {
  LocationIngestService({
    SupabaseClient? client,
    LocationThrottle? throttle,
    LocationHistoryQueue? historyQueue,
    DateTime Function()? monitoringClock,
    DateTime Function()? clock,
  }) : _supabase = client ?? Supabase.instance.client,
       _throttle = throttle ?? LocationThrottle(),
       _historyQueue = historyQueue ?? LocationHistoryQueue(client: client),
       _clock = clock ?? DateTime.now,
       _monitoringClock = monitoringClock ?? DateTime.now {
    _historyQueue.start();
  }

  final SupabaseClient _supabase;
  final LocationThrottle _throttle;
  final LocationThrottle _navThrottle = LocationThrottle(
    minInterval: LocationIngestConfig.navigationMinInterval,
    minDistanceMeters: LocationIngestConfig.navigationMinDistanceMeters,
  );
  final LocationHistoryQueue _historyQueue;
  final DateTime Function() _clock;
  final DateTime Function() _monitoringClock;

  DateTime? _lastRealtimePgAt;
  bool _realtimePgPending = false;
  String? _cachedProfileId;
  String? _cachedProfileUserId;
  bool _edgeUnavailable = false;
  DateTime? _lastMonitoringAttemptAt;
  String? _lastMonitoringOrderId;
  bool _monitoringPending = false;

  /// Resolve once at the GPS boundary; map/server coordinates are already resolved.
  LatLng resolveCoordinates({
    required LocationIngestCoordinateSpace coordinateSpace,
    required double lat,
    required double lng,
  }) => coordinateSpace.resolveCoordinates(
    email: _supabase.auth.currentUser?.email,
    lat: lat,
    lng: lng,
  );

  /// Idle discovery only: never creates delivery evidence or GPS order history.
  /// Validate browser accuracy separately while preserving measured coordinates
  /// and capture time. Delivery ingestion retains its stricter 50m threshold.
  Future<bool> ingestOnlinePresence({
    String? driverProfileId,
    String? driverUserId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? capturedAt,
    LocationIngestCoordinateSpace coordinateSpace =
        LocationIngestCoordinateSpace.rawGps,
  }) async {
    if ((driverProfileId == null && driverUserId == null) ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        capturedAt == null ||
        accuracy == null ||
        !PhysicalGpsPolicy.accepts(
          now: _clock(),
          capturedAt: capturedAt,
          accuracy: accuracy,
          onlinePresence: true,
        )) {
      return false;
    }
    final adjusted = resolveCoordinates(
      coordinateSpace: coordinateSpace,
      lat: lat,
      lng: lng,
    );
    // A heartbeat must confirm PG latest: dispatch reads drivers, not Redis.
    // Retry Edge on the next heartbeat even after an earlier outage.
    if (LocationIngestConfig.useEdgeIngest &&
        await _ingestViaEdge(
          driverProfileId: driverProfileId,
          driverUserId: driverUserId,
          lat: adjusted.latitude,
          lng: adjusted.longitude,
          heading: heading,
          speed: speed,
          force: true,
          requestTimeout: const Duration(seconds: 8),
        )) {
      return true;
    }
    return _ingestLocal(
      driverProfileId: driverProfileId,
      driverUserId: driverUserId,
      lat: adjusted.latitude,
      lng: adjusted.longitude,
      heading: heading,
      speed: speed,
      force: true,
      confirmLatest: true,
    ).timeout(const Duration(seconds: 8), onTimeout: () => false);
  }

  /// Ingest một sample GPS.
  ///
  /// [prioritySync]: đơn active — gửi Redis mỗi 5s, PG mỗi 10s.
  /// Broadcast/map dùng GPS riêng; [force] đồng bộ ngay tại mốc nghiệp vụ.
  Future<void> ingest({
    String? driverProfileId,
    String? driverUserId,
    String? orderId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? capturedAt,
    LatLng? monitoringPosition,
    bool force = false,
    bool prioritySync = false,
    LocationIngestCoordinateSpace coordinateSpace =
        LocationIngestCoordinateSpace.rawGps,
  }) async {
    if (driverProfileId == null &&
        (driverUserId == null || driverUserId.isEmpty)) {
      return;
    }

    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        !PhysicalGpsPolicy.accepts(
          now: _clock(),
          capturedAt: capturedAt,
          accuracy: accuracy,
        )) {
      return;
    }
    final adjusted = resolveCoordinates(
      coordinateSpace: coordinateSpace,
      lat: lat,
      lng: lng,
    );

    // Chạy trước lọc theo quãng đường: đứng yên vẫn có mẫu GPS mới hợp lệ.
    if (orderId != null && accuracy != null && capturedAt != null) {
      await _recordMonitoring(
        orderId,
        monitoringPosition ?? adjusted,
        accuracy,
        capturedAt,
      );
    }

    final throttle = prioritySync ? _navThrottle : _throttle;
    if (force) throttle.reset();
    final accepted = throttle.shouldAccept(
      lat: adjusted.latitude,
      lng: adjusted.longitude,
      now: _clock(),
    );
    if (!accepted && !force) return;

    // 1) Edge Redis (nếu có)
    if (LocationIngestConfig.useEdgeIngest && !_edgeUnavailable) {
      final ok = await _ingestViaEdge(
        driverProfileId: driverProfileId,
        driverUserId: driverUserId,
        orderId: orderId,
        lat: adjusted.latitude,
        lng: adjusted.longitude,
        heading: heading,
        speed: speed,
        force: force,
      );
      if (ok) {
        // Edge đã quản lý PG trên mọi producer, không PATCH bổ sung ở client.
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
      orderId: orderId,
      lat: adjusted.latitude,
      lng: adjusted.longitude,
      heading: heading,
      speed: speed,
      prioritySync: prioritySync,
      force: force,
    );
  }

  Future<bool> _ingestViaEdge({
    String? driverProfileId,
    String? driverUserId,
    String? orderId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    bool force = false,
    Duration requestTimeout = const Duration(seconds: 20),
  }) async {
    try {
      final res = await _supabase.functions
          .invoke(
            LocationIngestConfig.ingestFunctionName,
            body: {
              'driver_profile_id': ?driverProfileId,
              'driver_user_id': ?driverUserId,
              'order_id': ?orderId,
              'lat': lat,
              'lng': lng,
              'heading': ?heading,
              'speed': ?speed,
              if (force) 'force_pg_sync': true,
              'client_ts': _clock().toUtc().toIso8601String(),
            },
          )
          .timeout(requestTimeout);
      if (res.status >= 200 && res.status < 300) {
        final data = res.data;
        final pgUpdated = data is Map && data['pg_updated'] == true;
        if (pgUpdated) _lastRealtimePgAt = _clock();
        // Arrival/accept cần PG mới thật; fallback giữ tương thích Edge cũ.
        if (force && !pgUpdated) return false;
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

  Future<void> _recordMonitoring(
    String orderId,
    LatLng position,
    double accuracy,
    DateTime capturedAt,
  ) async {
    final now = _monitoringClock();
    if (_monitoringPending ||
        (_lastMonitoringOrderId == orderId &&
            _lastMonitoringAttemptAt != null &&
            now.difference(_lastMonitoringAttemptAt!) <
                const Duration(seconds: 5))) {
      return;
    }
    _monitoringPending = true;
    _lastMonitoringOrderId = orderId;
    _lastMonitoringAttemptAt = now;
    try {
      await _supabase
          .rpc(
            'record_driver_monitoring_position',
            params: {
              'p_order_id': orderId,
              'p_lat': position.latitude,
              'p_lng': position.longitude,
              'p_accuracy': accuracy,
              'p_captured_at': capturedAt.toUtc().toIso8601String(),
            },
          )
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      if (kDebugMode) debugPrint('[DriverMonitoring] sample pending: $error');
    } finally {
      _monitoringPending = false;
    }
  }

  Future<bool> _ingestLocal({
    String? driverProfileId,
    String? driverUserId,
    String? orderId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    bool prioritySync = false,
    bool force = false,
    bool confirmLatest = false,
  }) async {
    final ids = await _resolveIds(
      driverProfileId: driverProfileId,
      driverUserId: driverUserId,
    );
    if (ids == null) return false;

    final now = _clock();
    final updated = await _touchDriversOnly(
      driverProfileId: ids.profileId,
      driverUserId: ids.userId,
      lat: lat,
      lng: lng,
      prioritySync: prioritySync,
      resolvedProfileId: ids.profileId,
      force: force,
      confirmLatest: confirmLatest,
    );

    // Chỉ lưu history cho một đơn cụ thể; GPS Online chỉ cập nhật latest.
    if (orderId != null && orderId.isNotEmpty) {
      _historyQueue.enqueue(
        GpsHistoryPoint(
          driverProfileId: ids.profileId,
          orderId: orderId,
          lat: lat,
          lng: lng,
          heading: heading,
          speed: speed,
          createdAt: now,
        ),
      );
    }
    return updated;
  }

  /// UPDATE `drivers` latest — nguồn Realtime/poll cho map khách.
  Future<bool> _touchDriversOnly({
    String? driverProfileId,
    String? driverUserId,
    required double lat,
    required double lng,
    bool prioritySync = false,
    String? resolvedProfileId,
    bool force = false,
    bool confirmLatest = false,
  }) async {
    final interval = prioritySync
        ? LocationIngestConfig.navigationRealtimePgInterval
        : LocationIngestConfig.realtimePgInterval;
    final now = _clock();
    if (_realtimePgPending && !force) return false;
    if (!force &&
        _lastRealtimePgAt != null &&
        now.difference(_lastRealtimePgAt!) < interval) {
      return false;
    }

    _realtimePgPending = true;
    try {
      String? profileId = resolvedProfileId;
      if (profileId == null) {
        final ids = await _resolveIds(
          driverProfileId: driverProfileId,
          driverUserId: driverUserId,
        );
        profileId = ids?.profileId;
      }
      if (profileId == null) return false;

      final update = _supabase
          .from('drivers')
          .update({
            'current_lat': lat,
            'current_lng': lng,
            // timestamptz cần múi giờ rõ ràng; giờ local thiếu offset bị hiểu là UTC.
            'location_updated_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
          })
          .eq('id', profileId);
      if (confirmLatest) {
        final rows = await update.select('id');
        if (rows.isEmpty) {
          throw StateError('Latest GPS update was not persisted');
        }
      } else {
        await update;
      }
      _lastRealtimePgAt = now;
      if (kDebugMode) {
        debugPrint(
          '[LocationIngest] PG drivers touch '
          '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)} '
          'priority=$prioritySync',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationIngest] PG latest update failed: $e');
      }
      return false;
    } finally {
      _realtimePgPending = false;
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
      final response = await _supabase.rpc('get_my_driver_account_profile');
      if (response is! Map) return null;
      final row = Map<String, dynamic>.from(response);
      final resolvedProfileId = row['id']?.toString();
      final resolvedUserId = row['user_id']?.toString();
      if (resolvedProfileId == null ||
          resolvedProfileId.isEmpty ||
          resolvedUserId == null ||
          resolvedUserId.isEmpty) {
        return null;
      }
      if (driverProfileId != null &&
          driverProfileId.isNotEmpty &&
          driverProfileId != resolvedProfileId) {
        return null;
      }
      if (driverUserId != null &&
          driverUserId.isNotEmpty &&
          driverUserId != resolvedUserId) {
        return null;
      }
      _cachedProfileId = resolvedProfileId;
      _cachedProfileUserId = resolvedUserId;
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
