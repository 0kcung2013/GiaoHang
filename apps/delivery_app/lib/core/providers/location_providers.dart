import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../location/driver_location_producer_policy.dart';
import '../location/location_ingest_config.dart';
import '../models/driver_location_model.dart';
import '../services/location_service.dart';
import 'customer_providers.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final hasLocationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.requestPermission();
});

final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.getCurrentPosition();
});

final driverLocationModeProvider = StateProvider<DriverLocationMode>(
  (ref) => DriverLocationMode.deviceGps,
);

/// Order đang sở hữu quyền publish vị trí từ màn navigation.
///
/// Khi có order active, GPS nền ở dashboard phải dừng để không ghi đè vị trí
/// simulation/navigation vừa phát cho khách hàng.
final activeDriverNavigationOrderProvider = StateProvider<String?>(
  (ref) => null,
);

/// Stream GPS tài xế + ingest tối ưu (không ghi PG mỗi tick).
///
/// [driverId] = `drivers.id` (profile).
final driverLocationStreamProvider = StreamProvider.autoDispose
    .family<Position, String>((ref, driverId) {
      final locationMode = ref.watch(driverLocationModeProvider);
      final activeNavigationOrderId = ref.watch(
        activeDriverNavigationOrderProvider,
      );
      if (!DriverLocationProducerPolicy.canPublishBackgroundGps(
        activeNavigationOrderId,
      )) {
        return const Stream<Position>.empty();
      }

      final locationService = ref.watch(locationServiceProvider);
      final ingest = ref.watch(locationIngestServiceProvider);

      final controller = StreamController<Position>();
      Timer? presenceTimer;
      var presenceSyncInFlight = false;

      Future<void> syncPresence() async {
        if (presenceSyncInFlight) return;
        presenceSyncInFlight = true;
        try {
          final position = await locationService.getCurrentPosition();
          if (position == null || controller.isClosed) return;
          controller.add(position);
          await ingest.ingest(
            driverProfileId: driverId,
            lat: position.latitude,
            lng: position.longitude,
            heading: position.heading,
            speed: position.speed,
            coordinateSpace: locationMode.rawGpsCoordinateSpace,
          );
        } finally {
          presenceSyncInFlight = false;
        }
      }

      locationService.startTracking(
        // distanceFilter phía OS: lọc sớm trước throttle app.
        distanceFilterMeters: LocationIngestConfig.minDistanceMeters
            .round()
            .clamp(10, 100),
        onPosition: (position) {
          controller.add(position);
          unawaited(
            ingest.ingest(
              driverProfileId: driverId,
              lat: position.latitude,
              lng: position.longitude,
              heading: position.heading,
              speed: position.speed,
              coordinateSpace: locationMode.rawGpsCoordinateSpace,
            ),
          );
        },
        onError: (error) {
          debugPrint('[GPS] Tracking error: $error');
        },
      );

      unawaited(syncPresence());
      presenceTimer = Timer.periodic(
        LocationIngestConfig.onlinePresenceInterval,
        (_) => unawaited(syncPresence()),
      );

      ref.onDispose(() {
        presenceTimer?.cancel();
        locationService.stopTracking();
        controller.close();
      });

      return controller.stream;
    });

typedef LocationRealtimeRequest = ({String driverId, String orderId});

/// Vị trí tài xế live từ Realtime payload (tránh nhảy về tọa độ cũ khi re-fetch).
final liveDriverLatLngProvider =
    StateProvider.family<({double lat, double lng})?, String>(
      (ref, orderId) => null,
    );

final driverLocationRealtimeProvider = FutureProvider.autoDispose
    .family<void, LocationRealtimeRequest>((ref, request) async {
      final realtimeService = ref.watch(realtimeServiceProvider);
      debugPrint(
        '[LocationRealtime] subscribing driver=${request.driverId} '
        'order=${request.orderId}',
      );

      // A) Broadcast tức thì từ map tài xế
      realtimeService.subscribeToOrderDriverBroadcast(request.orderId, (
        lat,
        lng,
      ) {
        debugPrint(
          '[LocationRealtime] broadcast loc order=${request.orderId} '
          '$lat,$lng',
        );
        ref.read(liveDriverLatLngProvider(request.orderId).notifier).state = (
          lat: lat,
          lng: lng,
        );
      });

      // B) Postgres drivers UPDATE (backup)
      realtimeService.subscribeToDriverLocation(request.driverId, (newRecord) {
        final lat = _parseCoord(newRecord?['current_lat']);
        final lng = _parseCoord(newRecord?['current_lng']);
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          ref.read(liveDriverLatLngProvider(request.orderId).notifier).state = (
            lat: lat,
            lng: lng,
          );
        }
        ref.invalidate(assignedDriverProvider(request.orderId));
      });

      ref.onDispose(() async {
        await realtimeService.unsubscribe(
          'order_driver_loc:${request.orderId}',
        );
        await realtimeService.unsubscribe(
          'driver_location:${request.driverId}',
        );
      });
    });

double? _parseCoord(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

final lastDriverLocationProvider =
    FutureProvider.family<DriverLocationModel?, String>((ref, driverId) async {
      final service = ref.watch(driverServiceProvider);
      return service.getLastLocation(driverId);
    });
