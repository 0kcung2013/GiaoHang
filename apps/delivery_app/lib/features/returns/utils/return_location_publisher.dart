import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../core/location/driver_location_producer_policy.dart';
import '../../../core/location/location_ingest_service.dart';
import '../../../core/services/realtime_service.dart';

class ReturnLocationPublisher {
  const ReturnLocationPublisher({
    required this.realtimeService,
    required this.locationIngestService,
  });

  final RealtimeService realtimeService;
  final LocationIngestService locationIngestService;

  Future<void> publish({
    required String orderId,
    required String driverId,
    required LatLng position,
    bool force = false,
  }) async {
    final broadcast = realtimeService.broadcastDriverLocation(
      orderId: orderId,
      lat: position.latitude,
      lng: position.longitude,
    );
    final ingest = locationIngestService.ingest(
      driverUserId: driverId,
      lat: position.latitude,
      lng: position.longitude,
      prioritySync: true,
      force: force,
      coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
    );
    if (force) {
      await Future.wait([broadcast, ingest]);
    } else {
      unawaited(broadcast);
      unawaited(ingest);
    }
  }
}
