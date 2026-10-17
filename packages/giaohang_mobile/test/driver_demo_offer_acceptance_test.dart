import 'dart:async';

import 'package:giaohang_mobile/core/location/driver_demo_offer_acceptance.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/utils/geo_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final expected = GeoUtils.testDriverDemoPositions['taixe@gmail.com']!;
  const stale = LatLng(10.827950, 106.720965);

  test(
    'accept waits for the demo GPS write and confirms the backend origin',
    () async {
      final releaseWrite = Completer<void>();
      var stored = stale;
      LatLng? acceptedFrom;
      final pending = acceptAfterDemoLocationSync(
        mode: DriverLocationMode.demoHcm,
        email: 'taixe@gmail.com',
        trafficDemoKey: 'peak',
        publish: (position) async {
          await releaseWrite.future;
          stored = position;
        },
        readLatest: () async => stored,
        accept: () async => acceptedFrom = stored,
      );
      await Future<void>.delayed(Duration.zero);
      expect(acceptedFrom, isNull, reason: 'ETA must not use the previous GPS');
      releaseWrite.complete();
      await pending;
      expect(acceptedFrom, expected);
    },
  );

  test(
    'a swallowed or overwritten GPS update cannot accept from stale coordinates',
    () async {
      var accepted = false;
      await expectLater(
        acceptAfterDemoLocationSync(
          mode: DriverLocationMode.demoHcm,
          email: 'taixe@gmail.com',
          trafficDemoKey: 'peak',
          publish: (_) async {},
          readLatest: () async => stale,
          accept: () async => accepted = true,
        ),
        throwsException,
      );
      expect(accepted, isFalse);
    },
  );

  for (final mode in [
    DriverLocationMode.deviceGps,
    DriverLocationMode.demoCurrentPosition,
  ]) {
    test('$mode keeps the existing real-position acceptance flow', () async {
      var accepted = false;
      await acceptAfterDemoLocationSync(
        mode: mode,
        email: 'taixe@gmail.com',
        trafficDemoKey: 'peak',
        publish: (_) async => fail('Must not apply the fixed demo position'),
        readLatest: () async => fail('Must not apply the fixed demo position'),
        accept: () async => accepted = true,
      );
      expect(accepted, isTrue);
    });
  }

  test('ordinary orders do not reset the driver to a demo position', () async {
    var accepted = false;
    await acceptAfterDemoLocationSync(
      mode: DriverLocationMode.demoHcm,
      email: 'taixe@gmail.com',
      trafficDemoKey: null,
      publish: (_) async =>
          fail('Must not reset the driver for an ordinary order'),
      readLatest: () async =>
          fail('Must not reset the driver for an ordinary order'),
      accept: () async => accepted = true,
    );
    expect(accepted, isTrue);
  });
}
