import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService();

  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  Future<bool> requestPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse ||
          result == LocationPermission.always;
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('[GPS] Permission denied');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[GPS] getCurrentPosition timed out (web browser may have blocked location)');
          return Future.error('GPS timeout');
        },
      );
    } catch (e) {
      debugPrint('[GPS] getCurrentPosition error: $e');
      return null;
    }
  }

  void startTracking({
    required void Function(Position position) onPosition,
    void Function(String error)? onError,
    int distanceFilterMeters = 10,
  }) {
    if (_isTracking) return;

    _isTracking = true;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: distanceFilterMeters,
      ),
    ).listen(
      (position) {
        if (!_isTracking) return;
        onPosition(position);
      },
      onError: (error) {
        onError?.call(error.toString());
      },
    );
  }

  void stopTracking() {
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  void dispose() {
    stopTracking();
  }
}
