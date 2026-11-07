import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_mobile/core/services/location_service.dart';

import 'driver_presence_session_test.dart' show fix;
import 'location_acquisition_timeout_test.dart' show WebGpsPlatform;

class _OnlinePlatform extends WebGpsPlatform {
  final accuracies = <LocationAccuracy>[];

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    accuracies.add(locationSettings!.accuracy);
    return super.getPositionStream(locationSettings: locationSettings);
  }
}

void main() {
  test('concurrent Online callers share a watch and disposal cancels it', () {
    fakeAsync((time) {
      final previous = GeolocatorPlatform.instance;
      final platform = _OnlinePlatform();
      GeolocatorPlatform.instance = platform;
      final service = LocationService(isWeb: true);
      final first = service.getOnlinePosition();
      final second = service.getOnlinePosition();
      expect(identical(first, second), isTrue);
      Object? failure;
      unawaited(
        first.then(
          (_) => fail('Disposed request returned a fix'),
          onError: (Object error) => failure = error,
        ),
      );
      time.flushMicrotasks();
      expect(platform.watches, 1);
      service.dispose();
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 30));
      expect(failure, isNotNull);
      expect(platform.watches, 1);
      expect(platform.cancellations, 1);
      GeolocatorPlatform.instance = previous;
      time.flushMicrotasks();
    });
  });

  test('a separate eight-second read cannot cancel the Online watch', () {
    fakeAsync((time) {
      final previous = GeolocatorPlatform.instance;
      final platform = _OnlinePlatform();
      GeolocatorPlatform.instance = platform;
      final service = LocationService(isWeb: true);
      Position? received;
      Object? failure;
      unawaited(
        service.getOnlinePosition().then(
          (p) => received = p,
          onError: (Object error) => failure = error,
        ),
      );
      unawaited(service.getCurrentPosition());
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 9));
      time.flushMicrotasks();
      expect(failure, isNull);
      platform.controllers.first.add(fix(DateTime.now()));
      time.flushMicrotasks();
      expect(received, isNotNull);
      expect(platform.cancellations, platform.watches);
      service.dispose();
      GeolocatorPlatform.instance = previous;
      time.flushMicrotasks();
    });
  });

  test('Online leaves an existing tracking subscription running', () {
    fakeAsync((time) {
      final previous = GeolocatorPlatform.instance;
      final platform = _OnlinePlatform();
      GeolocatorPlatform.instance = platform;
      final service = LocationService(isWeb: true);
      var tracked = 0;
      service.startTracking(onPosition: (_) => tracked++);
      Position? received;
      unawaited(service.getOnlinePosition().then((p) => received = p));
      time.flushMicrotasks();
      platform.controllers.first.add(fix(DateTime.now()));
      time.flushMicrotasks();
      expect(received, isNotNull);
      expect(service.isTracking, isTrue);
      expect(platform.cancellations, 0);
      platform.controllers.first.add(fix(DateTime.now()));
      time.flushMicrotasks();
      expect(tracked, 2);
      service.dispose();
      GeolocatorPlatform.instance = previous;
      time.flushMicrotasks();
    });
  });

  test('Online keeps a cold browser fix alive beyond eight seconds', () {
    fakeAsync((time) {
      final previous = GeolocatorPlatform.instance;
      final platform = _OnlinePlatform();
      GeolocatorPlatform.instance = platform;
      final service = LocationService(isWeb: true);
      Position? received;
      Object? failure;
      unawaited(
        service.getOnlinePosition().then(
          (p) => received = p,
          onError: (Object error) => failure = error,
        ),
      );
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 9));
      time.flushMicrotasks();
      expect(
        failure,
        isNull,
        reason: 'A slow first fix must not be cancelled at 8s',
      );
      expect(platform.cancellations, 0);
      platform.controllers.first.add(fix(DateTime.now()));
      time.flushMicrotasks();
      expect(received, isNotNull);
      expect(platform.cancellations, platform.watches);
      service.dispose();
      GeolocatorPlatform.instance = previous;
      time.flushMicrotasks();
    });
  });

  test('Online tries a browser network fix without relaxing GPS quality', () {
    fakeAsync((time) {
      final previous = GeolocatorPlatform.instance;
      final platform = _OnlinePlatform();
      GeolocatorPlatform.instance = platform;
      final service = LocationService(isWeb: true);
      Position? received;
      Object? failure;
      unawaited(
        service.getOnlinePosition().then(
          (p) => received = p,
          onError: (Object error) => failure = error,
        ),
      );
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 8));
      time.flushMicrotasks();
      expect(platform.accuracies, [
        LocationAccuracy.high,
        LocationAccuracy.medium,
      ]);
      platform.controllers.last.add(fix(DateTime.now(), accuracy: 5000));
      time.flushMicrotasks();
      expect(received, isNull);
      expect(failure, isNull);
      platform.controllers.last.add(fix(DateTime.now(), accuracy: 126));
      time.flushMicrotasks();
      expect(received?.accuracy, 126);
      service.dispose();
      GeolocatorPlatform.instance = previous;
      time.flushMicrotasks();
    });
  });

  test(
    'a browser that supplies no position finishes Online after 30 seconds',
    () {
      fakeAsync((time) {
        final previous = GeolocatorPlatform.instance;
        final platform = _OnlinePlatform();
        GeolocatorPlatform.instance = platform;
        final service = LocationService(isWeb: true);
        Object? failure;
        unawaited(
          service.getOnlinePosition().then(
            (_) => fail('A position was fabricated'),
            onError: (Object error) => failure = error,
          ),
        );
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 29));
        time.flushMicrotasks();
        expect(failure, isNull);
        time.elapse(const Duration(seconds: 1));
        time.flushMicrotasks();
        expect(failure, isNotNull);
        expect(failure.toString(), isNot(contains('8 giây')));
        expect(platform.cancellations, platform.watches);
        service.dispose();
        GeolocatorPlatform.instance = previous;
        time.flushMicrotasks();
      });
    },
  );

  test('Online permission denial stops all GPS work immediately', () {
    fakeAsync((time) {
      final previous = GeolocatorPlatform.instance;
      final platform = _OnlinePlatform();
      GeolocatorPlatform.instance = platform;
      final service = LocationService(isWeb: true);
      Object? failure;
      unawaited(
        service.getOnlinePosition().then(
          (_) => fail('Denied permission must not yield a position'),
          onError: (Object error) => failure = error,
        ),
      );
      time.flushMicrotasks();
      platform.controllers.first.addError(
        const PermissionDeniedException('blocked'),
      );
      time.flushMicrotasks();
      expect(failure, isNotNull);
      time.elapse(const Duration(seconds: 30));
      expect(platform.watches, 1);
      expect(platform.cancellations, 1);
      service.dispose();
      GeolocatorPlatform.instance = previous;
      time.flushMicrotasks();
    });
  });
}
