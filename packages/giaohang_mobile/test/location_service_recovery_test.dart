import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_mobile/core/services/location_service.dart';
import 'driver_presence_session_test.dart' show fix;

class _Platform extends GeolocatorPlatform {
  final streams = <StreamController<Position>>[];
  bool permissionThrows = false;
  LocationAccuracy? accuracy;
  @override
  Future<LocationPermission> checkPermission() async {
    if (permissionThrows) {
      throw StateError('permission temporarily unavailable');
    }
    return LocationPermission.whileInUse;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => fix(DateTime.now());
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    accuracy = locationSettings?.accuracy;
    final stream = StreamController<Position>();
    streams.add(stream);
    return stream.stream;
  }
}

void main() {
  test(
    'stream errors release tracking and can restart; stopping idle leaves active GPS intact',
    () async {
      final previous = GeolocatorPlatform.instance;
      final platform = _Platform();
      GeolocatorPlatform.instance = platform;
      final idle = LocationService(), active = LocationService();
      addTearDown(() {
        idle.dispose();
        active.dispose();
        for (final stream in platform.streams) {
          unawaited(stream.close());
        }
        GeolocatorPlatform.instance = previous;
      });
      var idleFixes = 0, activeFixes = 0;
      void startIdle() => idle.startTracking(onPosition: (_) => idleFixes++);
      startIdle();
      expect(platform.accuracy, LocationAccuracy.high);
      platform.streams[0].addError(StateError('GPS paused'));
      await Future<void>.delayed(Duration.zero);
      expect(idle.isTracking, isFalse);
      startIdle();
      platform.streams[1].add(fix(DateTime.now()));
      await Future<void>.delayed(Duration.zero);
      expect(idleFixes, 1);
      active.startTracking(onPosition: (_) => activeFixes++);
      idle.stopTracking();
      platform.streams[2].add(fix(DateTime.now()));
      await Future<void>.delayed(Duration.zero);
      expect(activeFixes, 1);
      expect(active.isTracking, isTrue);
      await platform.streams[2].close();
      expect(active.isTracking, isFalse);
    },
  );

  test(
    'permission plugin error is recoverable by the next acquisition',
    () async {
      final previous = GeolocatorPlatform.instance;
      final platform = _Platform()..permissionThrows = true;
      GeolocatorPlatform.instance = platform;
      addTearDown(() => GeolocatorPlatform.instance = previous);
      final service = LocationService();
      expect(await service.getCurrentPosition(), isNull);
      platform.permissionThrows = false;
      expect(await service.getCurrentPosition(), isNotNull);
    },
  );
}
