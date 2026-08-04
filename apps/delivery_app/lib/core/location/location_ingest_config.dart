/// Cấu hình pipeline GPS: throttle → hot store → queue history → Postgres.
///
/// Mục tiêu DATN: giảm ghi PostgreSQL trực tiếp mà vẫn giữ tracking realtime
/// (UPDATE `drivers` theo chu kỳ) và history bất đồng bộ (batch).
class LocationIngestConfig {
  LocationIngestConfig._();

  /// Khoảng cách tối thiểu (m) giữa 2 lần ingest được chấp nhận.
  static const double minDistanceMeters = 25;

  /// Heartbeat khi tài xế online chờ đơn để tọa độ matching không bị stale.
  static const Duration onlinePresenceInterval = Duration(seconds: 60);

  /// Thời gian tối thiểu giữa 2 lần ingest (client throttle).
  static const Duration minInterval = Duration(seconds: 5);

  /// Chu kỳ UPDATE `drivers` bình thường (hot path fallback).
  static const Duration realtimePgInterval = Duration(seconds: 3);

  /// Khi đang navigation — sync khách mượt hơn (vẫn không ghi history mỗi tick).
  static const Duration navigationRealtimePgInterval = Duration(seconds: 2);

  /// Throttle nới lỏng khi navigation (ưu tiên đồng bộ map khách).
  static const Duration navigationMinInterval = Duration(seconds: 2);
  static const double navigationMinDistanceMeters = 12;

  /// Chu kỳ flush history queue → bulk insert Postgres (fallback client).
  static const Duration historyFlushInterval = Duration(seconds: 30);

  /// Số điểm tối thiểu trong queue trước khi flush sớm.
  static const int historyFlushMinBatch = 8;

  /// Số điểm tối đa mỗi lần bulk insert.
  static const int historyFlushMaxBatch = 40;

  /// Gọi Edge Function `ingest-driver-location` (Redis + queue server).
  /// false = fallback local: throttle + PG latest thưa + batch history client.
  static const bool useEdgeIngest = true;

  /// Tên Edge Function ingest.
  static const String ingestFunctionName = 'ingest-driver-location';

  /// Tên Edge Function flush history (cron/manual).
  static const String flushFunctionName = 'flush-gps-history';

  /// Tên Edge Function tìm nearest qua Redis GEO.
  static const String nearestFunctionName = 'find-nearest-drivers-redis';
}
