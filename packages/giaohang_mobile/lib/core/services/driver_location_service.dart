import '../location/location_ingest_service.dart';

/// Upload vị trí driver qua pipeline tối ưu (throttle → Redis/queue → PG).
///
/// API cũ: [driverId] = `drivers.user_id` (thường là `orders.driver_id`).
class DriverLocationService {
  DriverLocationService({LocationIngestService? ingest})
    : _ingest = ingest ?? LocationIngestService();

  final LocationIngestService _ingest;

  Future<void> updateLocation({
    required String driverId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) {
    return _ingest.ingest(
      driverUserId: driverId,
      lat: lat,
      lng: lng,
      heading: heading,
      speed: speed,
    );
  }
}
