import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_mobile/core/location/driver_presence_session.dart';
import 'package:giaohang_mobile/core/services/location_service.dart';

Position fix(DateTime at, {double accuracy = 126}) => Position(
  latitude: 10.8,
  longitude: 106.7,
  timestamp: at,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class Gps extends LocationService {
  Gps(this.sample);
  Future<Position?> Function() sample;
  int starts = 0, stops = 0;
  bool tracking = false;
  late void Function(Position) emit;
  late void Function(String)? fail;
  @override
  bool get isTracking => tracking;
  @override
  Future<Position?> getCurrentPosition() => sample();
  @override
  void startTracking({
    required void Function(Position) onPosition,
    void Function(String)? onError,
    int distanceFilterMeters = 10,
  }) {
    starts++;
    tracking = true;
    emit = onPosition;
    fail = onError;
  }

  @override
  void stopTracking() {
    stops++;
    tracking = false;
  }
}

void main() {
  test(
    'stationary driver renews confirmed discovery every 30s for 10 minutes',
    () {
      fakeAsync((time) {
        final start = DateTime.utc(2026, 11, 3);
        DateTime now() => start.add(time.elapsed);
        final gps = Gps(() async => fix(now()));
        final writes = <DateTime>[];
        final session = DriverPresenceSession(
          location: gps,
          clock: now,
          publish: (p) async {
            writes.add(p.timestamp);
            return true;
          },
          onPosition: (_) {},
        );
        session.start();
        time.flushMicrotasks();
        time.elapse(const Duration(minutes: 10));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.ready);
        expect(writes, hasLength(21));
        expect(gps.starts, 1);
        expect(writes.last, now());
        session.dispose();
        time.flushMicrotasks();
        time.elapse(const Duration(minutes: 4));
        expect(writes, hasLength(21));
        expect(gps.stops, 1);
      });
    },
  );

  test(
    'GPS quality, denied permission and transport errors recover without reload',
    () {
      fakeAsync((time) {
        final start = DateTime.utc(2026, 11, 3);
        DateTime now() => start.add(time.elapsed);
        final gps = Gps(() async => null);
        var synced = false;
        var writes = 0;
        final session = DriverPresenceSession(
          location: gps,
          clock: now,
          publish: (p) async {
            writes++;
            return synced;
          },
          onPosition: (_) {},
        );
        session.start();
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.gpsUnavailable);
        gps.sample = () async => fix(now(), accuracy: 300);
        time.elapse(const Duration(seconds: 10));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.inaccurate);
        expect(writes, 0);
        gps.sample = () async =>
            fix(now().subtract(const Duration(minutes: 5)));
        time.elapse(const Duration(seconds: 10));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.stale);
        expect(writes, 0);
        gps.sample = () async => fix(now());
        time.elapse(const Duration(seconds: 10));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.syncFailed);
        synced = true;
        time.elapse(const Duration(seconds: 10));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.ready);
        gps.tracking = false;
        gps.fail!('stream stopped');
        time.elapse(const Duration(seconds: 10));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.ready);
        expect(gps.starts, 2);
        session.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test('hung acquisition times out and the next sample recovers', () {
    fakeAsync((time) {
      final start = DateTime.utc(2026, 11, 3);
      DateTime now() => start.add(time.elapsed);
      final pending = Completer<Position?>();
      final gps = Gps(() => pending.future);
      final session = DriverPresenceSession(
        location: gps,
        clock: now,
        publish: (_) async => true,
        onPosition: (_) {},
      );
      session.start();
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 21));
      time.flushMicrotasks();
      expect(session.status, DriverPresenceStatus.gpsTimedOut);
      gps.sample = () async => fix(now());
      time.elapse(const Duration(seconds: 21));
      time.flushMicrotasks();
      expect(session.status, DriverPresenceStatus.ready);
      session.dispose();
      pending.complete(fix(now()));
      time.flushMicrotasks();
    });
  });

  test(
    'an older success cannot hide a newer GPS error or restore stale readiness',
    () {
      fakeAsync((time) {
        final start = DateTime.utc(2026, 11, 3);
        DateTime now() => start.add(time.elapsed);
        final pending = Completer<bool>();
        final gps = Gps(() async => fix(now()));
        final session = DriverPresenceSession(
          location: gps,
          clock: now,
          publish: (_) => pending.future,
          onPosition: (_) {},
        );
        session.start();
        time.flushMicrotasks();
        gps.emit(fix(now(), accuracy: 300));
        pending.complete(true);
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.inaccurate);
        session.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test('late GPS capture after logout cannot publish', () {
    fakeAsync((time) {
      final pending = Completer<Position?>();
      var writes = 0;
      final session = DriverPresenceSession(
        location: Gps(() => pending.future),
        publish: (_) async {
          writes++;
          return true;
        },
        onPosition: (_) {},
      );
      session.start();
      session.dispose();
      pending.complete(fix(DateTime.now()));
      time.flushMicrotasks();
      expect(writes, 0);
    });
  });

  test(
    'resume immediately clears stale readiness while the new GPS request is pending',
    () {
      fakeAsync((time) {
        final start = DateTime.utc(2026, 11, 3);
        DateTime now() => start.add(time.elapsed);
        final gps = Gps(() async => fix(now()));
        final session = DriverPresenceSession(
          location: gps,
          clock: now,
          publish: (_) async => true,
          onPosition: (_) {},
        );
        session.start();
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.ready);
        time.elapseBlocking(const Duration(minutes: 5));
        final pending = Completer<Position?>();
        gps.sample = () => pending.future;
        unawaited(session.refresh());
        expect(session.status, DriverPresenceStatus.stale);
        pending.complete(fix(now()));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.ready);
        gps.emit(fix(now().subtract(const Duration(minutes: 10))));
        time.flushMicrotasks();
        expect(session.status, DriverPresenceStatus.ready);
        session.dispose();
        time.flushMicrotasks();
      });
    },
  );

  for (final accuracy in [126.0, 201.0]) {
    test(
      'Online confirmation validates the new capture at accuracy $accuracy',
      () async {
        final gps = Gps(() async => fix(DateTime.now(), accuracy: accuracy));
        if (accuracy <= 200) {
          expect((await gps.getOnlinePosition()).accuracy, accuracy);
        } else {
          await expectLater(gps.getOnlinePosition(), throwsException);
        }
      },
    );
  }
  test(
    'Online confirmation rejects a GPS capture older than 90 seconds',
    () async {
      final gps = Gps(
        () async => fix(DateTime.now().subtract(const Duration(minutes: 3))),
      );
      await expectLater(gps.getOnlinePosition(), throwsException);
    },
  );
}
