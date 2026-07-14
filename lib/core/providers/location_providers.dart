import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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

final driverLocationStreamProvider =
    StreamProvider.family<Position, String>((ref, driverId) {
  final locationService = ref.watch(locationServiceProvider);
  final driverService = ref.watch(driverServiceProvider);

  final controller = StreamController<Position>();

  locationService.startTracking(
    onPosition: (position) {
      controller.add(position);
      driverService.updateLocation(
        driverId: driverId,
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading,
      );
    },
    onError: (error) {
      debugPrint('[GPS] Tracking error: $error');
    },
  );

  ref.onDispose(() {
    locationService.stopTracking();
    controller.close();
  });

  return controller.stream;
});

typedef LocationRealtimeRequest = ({String driverId, String orderId});

final driverLocationRealtimeProvider =
    FutureProvider.family<void, LocationRealtimeRequest>((
      ref,
      request,
    ) async {
      final realtimeService = ref.watch(realtimeServiceProvider);
      debugPrint(
        '[LocationRealtime] subscribing for driverId=${request.driverId}',
      );

      realtimeService.subscribeToDriverLocation(request.driverId, () {
        debugPrint(
          '[LocationRealtime] location changed invalidating '
          'driverId=${request.driverId}',
        );
        ref.invalidate(assignedDriverProvider(request.orderId));
      });

      ref.onDispose(() async {
        debugPrint(
          '[LocationRealtime] unsubscribing driverId=${request.driverId}',
        );
        await realtimeService.unsubscribe('driver_location:${request.driverId}');
      });
    });

final lastDriverLocationProvider =
    FutureProvider.family<DriverLocationModel?, String>((
      ref,
      driverId,
    ) async {
      final service = ref.watch(driverServiceProvider);
      return service.getLastLocation(driverId);
    });
