import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/driver_arrival_fix.dart';
import '../location/driver_location_producer_policy.dart';
import '../location/driver_presence_session.dart';
import '../location/physical_gps_policy.dart';
import '../services/location_service.dart';
import 'customer_providers.dart';
import 'location_providers.dart';

// A late disposal of idle discovery cannot stop the active-delivery subscriber.
final driverOnlineLocationServiceProvider =
    Provider.autoDispose<LocationService>((ref) {
      final service = LocationService();
      ref.onDispose(service.dispose);
      return service;
    });

final driverPresenceSessionProvider = Provider.autoDispose
    .family<DriverPresenceSession, String>((ref, profileId) {
      final mode = ref.watch(driverLocationModeProvider);
      final ingest = ref.watch(locationIngestServiceProvider);
      final session = DriverPresenceSession(
        location: ref.watch(driverOnlineLocationServiceProvider),
        publish: (p) => ingest.ingestOnlinePresence(
          driverProfileId: profileId,
          lat: p.latitude,
          lng: p.longitude,
          accuracy: p.accuracy,
          capturedAt: p.timestamp,
          heading: p.heading,
          speed: p.speed,
          coordinateSpace: mode.rawGpsCoordinateSpace,
        ),
        onPosition: (p) {
          final point = ingest.resolveCoordinates(
            coordinateSpace: mode.rawGpsCoordinateSpace,
            lat: p.latitude,
            lng: p.longitude,
          );
          ref.read(driverPhysicalPositionProvider.notifier).state = point;
          if (PhysicalGpsPolicy.accepts(
            now: DateTime.now(),
            capturedAt: p.timestamp,
            accuracy: p.accuracy,
          )) {
            ref
                .read(driverArrivalFixProvider.notifier)
                .state = DriverArrivalFix(
              position: point,
              capturedAt: p.timestamp,
              accuracy: p.accuracy,
              mode: mode,
              simulated: mode != DriverLocationMode.deviceGps,
            );
          }
        },
      );
      ref.onDispose(session.dispose);
      // Starting on listen keeps provider construction free of state mutations.
      Future.microtask(session.start);
      return session;
    });

final driverOnlinePresenceProvider = StreamProvider.autoDispose
    .family<DriverPresenceStatus, String>((ref, profileId) async* {
      final session = ref.watch(driverPresenceSessionProvider(profileId));
      yield session.status;
      yield* session.changes;
    });
