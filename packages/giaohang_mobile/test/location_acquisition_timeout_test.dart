import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_mobile/core/services/location_service.dart';
import 'package:giaohang_mobile/core/location/location_failure.dart';
import 'package:giaohang_mobile/core/location/driver_presence_session.dart';
import 'driver_presence_session_test.dart' show fix;

class WebGpsPlatform extends GeolocatorPlatform {
  int watches = 0, cancellations = 0, oneShots = 0;
  final controllers = <StreamController<Position>>[];
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    oneShots++;
    return Completer<Position>().future;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    watches++;
    final c = StreamController<Position>(onCancel: () => cancellations++);
    controllers.add(c);
    return c.stream;
  }
}

class PendingGpsPlatform extends GeolocatorPlatform {
  int requests = 0;
  LocationPermission permission = LocationPermission.whileInUse;
  final pending = Completer<Position>();
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() =>
      Completer<LocationPermission>().future;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    requests++;
    return pending.future;
  }
}

void main() {
  test(
    'idle session restarts a silently stalled browser watch and accepts its next capture',
    () {
      fakeAsync((time) {
        final previous = GeolocatorPlatform.instance;
        final platform = WebGpsPlatform();
        GeolocatorPlatform.instance = platform;
        final start = DateTime.now();
        DateTime now() => start.add(time.elapsed);
        final service = LocationService(isWeb: true);
        final session = DriverPresenceSession(
          location: service,
          clock: now,
          publish: (_) async => true,
          onPosition: (_) {},
        );
        session.start();
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 8));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.gpsTimedOut);
        expect(
          platform.cancellations,
          0,
          reason: 'Do not interrupt a cold GPS fix after only 8 seconds',
        );
        time.elapse(const Duration(seconds: 40));
        time.flushMicrotasks();
        expect(platform.cancellations, 1);
        time.elapse(const Duration(seconds: 12));
        time.flushMicrotasks();
        expect(platform.watches, 2);
        platform.controllers.last.add(fix(now()));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.ready);
        session.dispose();
        service.dispose();
        time.flushMicrotasks();
        GeolocatorPlatform.instance = previous;
      });
    },
  );
  test(
    'web GPS deadline cancels the native browser watch rather than abandoning a request',
    () {
      fakeAsync((time) {
        final previous = GeolocatorPlatform.instance;
        final platform = WebGpsPlatform();
        GeolocatorPlatform.instance = platform;
        final service = LocationService(isWeb: true);
        var finished = false;
        unawaited(
          service.getCurrentPosition().then((p) {
            expect(p, isNull);
            finished = true;
          }),
        );
        time.flushMicrotasks();
        expect(platform.watches, 1);
        expect(platform.oneShots, 0);
        time.elapse(const Duration(seconds: 8));
        time.flushMicrotasks();
        expect(finished, isTrue);
        expect(platform.cancellations, 1);
        expect(service.lastFailure, LocationFailure.timeout);
        service.dispose();
        GeolocatorPlatform.instance = previous;
        time.flushMicrotasks();
      });
    },
  );

  for (final isWeb in [true, false]) {
    test(
      'one-shot shares active watch and reuses only a fresh measured capture: web=$isWeb',
      () {
        fakeAsync((time) {
          final previous = GeolocatorPlatform.instance;
          final platform = WebGpsPlatform();
          GeolocatorPlatform.instance = platform;
          final service = LocationService(isWeb: isWeb);
          service.startTracking(onPosition: (_) {});
          Position? received;
          unawaited(service.getCurrentPosition().then((p) => received = p));
          time.flushMicrotasks();
          final capture = fix(DateTime.now());
          platform.controllers.single.add(capture);
          time.flushMicrotasks();
          expect(received, same(capture));
          unawaited(
            service.getCurrentPosition().then((p) => expect(p, same(capture))),
          );
          time.flushMicrotasks();
          expect(platform.watches, 1);
          expect(platform.oneShots, 0);
          expect(platform.cancellations, 0);
          service.dispose();
          time.flushMicrotasks();
          expect(platform.cancellations, 1);
          GeolocatorPlatform.instance = previous;
        });
      },
    );
  }

  for (final failure in [
    const PermissionDeniedException('blocked'),
    const PositionUpdateException('provider unavailable'),
  ]) {
    test('web preserves the actual failure category: $failure', () {
      fakeAsync((time) {
        final previous = GeolocatorPlatform.instance;
        final platform = WebGpsPlatform();
        GeolocatorPlatform.instance = platform;
        final service = LocationService(isWeb: true);
        unawaited(service.getCurrentPosition());
        time.flushMicrotasks();
        platform.controllers.single.addError(failure);
        time.flushMicrotasks();
        expect(
          service.lastFailure,
          failure is PermissionDeniedException
              ? LocationFailure.permissionDenied
              : LocationFailure.unavailable,
        );
        expect(platform.cancellations, 1);
        service.dispose();
        GeolocatorPlatform.instance = previous;
        time.flushMicrotasks();
      });
    });
  }
  for (final permission in [
    LocationPermission.whileInUse,
    LocationPermission.denied,
  ]) {
    test(
      'whole acquisition finishes within 8 seconds even when plugin hangs: $permission',
      () {
        fakeAsync((time) {
          final previous = GeolocatorPlatform.instance;
          final platform = PendingGpsPlatform()..permission = permission;
          GeolocatorPlatform.instance = platform;
          final service = LocationService();
          var finished = false;
          unawaited(service.getCurrentPosition().then((_) => finished = true));
          time.flushMicrotasks();
          time.elapse(const Duration(seconds: 8));
          time.flushMicrotasks();
          GeolocatorPlatform.instance = previous;
          service.dispose();
          expect(
            finished,
            isTrue,
            reason: 'The browser/plugin timeout cannot be trusted',
          );
        });
      },
    );
  }
  test('concurrent reads share a single acquisition', () {
    fakeAsync((time) {
      final previous = GeolocatorPlatform.instance;
      final platform = PendingGpsPlatform();
      GeolocatorPlatform.instance = platform;
      final service = LocationService();
      unawaited(service.getCurrentPosition());
      unawaited(service.getCurrentPosition());
      time.flushMicrotasks();
      GeolocatorPlatform.instance = previous;
      service.dispose();
      expect(platform.requests, 1);
    });
  });
}
