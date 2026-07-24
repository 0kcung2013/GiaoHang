import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_ingest_config.dart';

/// Một điểm GPS chờ bulk insert Postgres (cold path).
class GpsHistoryPoint {
  const GpsHistoryPoint({
    required this.driverProfileId,
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    required this.createdAt,
  });

  final String driverProfileId;
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final DateTime createdAt;

  Map<String, dynamic> toDriverLocationsRow() {
    return {
      'driver_id': driverProfileId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'is_active': true,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Queue client-side + flush định kỳ (fallback khi chưa có Redis worker).
///
/// Không thay Kafka: đủ cho DATN, giảm N INSERT lẻ thành 1 bulk.
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

  /// Bulk insert tối đa [maxBatch] điểm vào `driver_locations`.
  Future<int> flush() async {
    if (_flushing || _queue.isEmpty) return 0;
    _flushing = true;
    try {
      final batch = <GpsHistoryPoint>[];
      while (_queue.isNotEmpty && batch.length < maxBatch) {
        batch.add(_queue.removeFirst());
      }
      if (batch.isEmpty) return 0;

      final rows = batch.map((e) => e.toDriverLocationsRow()).toList();
      await _supabase.from('driver_locations').insert(rows);

      if (kDebugMode) {
        debugPrint(
          '[GpsHistoryQueue] bulk insert ${rows.length} points '
          '(remaining=${_queue.length})',
        );
      }
      return rows.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GpsHistoryQueue] flush failed: $e');
      }
      // Mất batch khi lỗi — tránh queue phình vô hạn offline.
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
