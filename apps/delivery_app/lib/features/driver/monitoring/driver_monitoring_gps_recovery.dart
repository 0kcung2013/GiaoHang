import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/location/driver_active_delivery_tracking_policy.dart';
import '../../../core/location/driver_foreground_location_service.dart';
import '../../../core/location/driver_location_producer_policy.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/location_providers.dart';
import '../../../core/providers/driver_nav_session_provider.dart';
import 'driver_monitoring_providers.dart';

Future<void> recoverDriverOrderGps(
  WidgetRef ref, {
  required String orderId,
  required String userId,
}) async {
  final mode = ref.read(driverLocationModeProvider);
  final driver = await ref.read(driverByUserIdProvider(userId).future);
  if (!ref.context.mounted) return;
  if (driver == null) throw StateError('DRIVER_PROFILE_REQUIRED');
  final ingest = ref.read(locationIngestServiceProvider);
  if (DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
    isWeb: kIsWeb,
    locationMode: mode,
  )) {
    final session = ref.read(driverNavSessionsProvider)[orderId];
    final lat = session?.lat ?? driver.currentLat;
    final lng = session?.lng ?? driver.currentLng;
    if (lat == null || lng == null) throw StateError('DEMO_LOCATION_REQUIRED');
    await ingest.ingest(
      driverProfileId: driver.id,
      driverUserId: userId,
      orderId: orderId,
      lat: lat,
      lng: lng,
      accuracy: 0,
      capturedAt: DateTime.now(),
      prioritySync: true,
      coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
    );
  } else {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('LOCATION_PERMISSION_REQUIRED');
    }
    if (!ref.context.mounted) return;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    if (!ref.context.mounted) return;
    await DriverForegroundLocationService.start(
      driverProfileId: driver.id,
      driverUserId: userId,
      orderId: orderId,
    );
    await ingest.ingest(
      driverProfileId: driver.id,
      driverUserId: userId,
      orderId: orderId,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      capturedAt: position.timestamp,
      prioritySync: true,
      coordinateSpace: mode.rawGpsCoordinateSpace,
    );
  }
  if (ref.context.mounted) ref.invalidate(driverMonitoringProvider(orderId));
}
