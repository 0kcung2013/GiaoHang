import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_ingest_config.dart';

/// Một điểm GPS chờ gửi lại Edge ingest khi đường truyền tạm lỗi.
class GpsHistoryPoint {
  const GpsHistoryPoint({
    required this.driverProfileId,
    required this.orderId,
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    required this.createdAt,
  });

  final String driverProfileId;
  final String orderId;
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final DateTime createdAt;

  Map<String, dynamic> toEdgeBody() {
    return {
      'driver_profile_id': driverProfileId,
      'order_id': orderId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'client_ts': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// Queue client-side + thử gửi lại Edge Function định kỳ.
///
/// Fallback này không ghi lịch sử vào PostgreSQL. Khi Edge hoạt động lại, điểm
/// được đưa vào Redis queue và cron sẽ đóng gói sang Cloudflare R2.
class LocationHistoryQueue {
  LocationHistoryQueue({
    SupabaseClient? client,
    this.flushInterval = LocationIngestConfig.historyFlushInterval,
    this.minBatch = LocationIngestConfig.historyFlushMinBatch,
    this.maxBatch = LocationIngestConfig.historyFlushMaxBatch,
  }) : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final Duration flushInterval;
  final int minBatch;
  final int maxBatch;

  final Queue<GpsHistoryPoint> _queue = Queue<GpsHistoryPoint>();
  Timer? _timer;
  bool _flushing = false;

  int get length => _queue.length;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void enqueue(GpsHistoryPoint point) {
    _queue.addLast(point);
    if (_queue.length >= minBatch) {
      unawaited(flush());
    }
  }

  /// Gửi lại tối đa [maxBatch] điểm qua Edge ingest.
  Future<int> flush() async {
    if (_flushing || _queue.isEmpty) return 0;
    _flushing = true;
    try {
      final batch = <GpsHistoryPoint>[];
      while (_queue.isNotEmpty && batch.length < maxBatch) {
        batch.add(_queue.removeFirst());
      }
      if (batch.isEmpty) return 0;

      var accepted = 0;
      for (final point in batch) {
        final response = await _supabase.functions.invoke(
          LocationIngestConfig.ingestFunctionName,
          body: point.toEdgeBody(),
        );
        if (response.status >= 200 && response.status < 300) accepted += 1;
      }

      if (kDebugMode) {
        debugPrint(
          '[GpsHistoryQueue] re-ingested $accepted/${batch.length} points '
          '(remaining=${_queue.length})',
        );
      }
      return accepted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GpsHistoryQueue] flush failed: $e');
      }
      // Bỏ batch lỗi để tránh queue RAM phình vô hạn khi thiết bị offline lâu.
      return 0;
    } finally {
      _flushing = false;
    }
  }

  Future<void> dispose() async {
    stop();
    await flush();
  }
}
