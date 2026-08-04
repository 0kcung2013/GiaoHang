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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return position;
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

    _positionStream =
        Geolocator.getPositionStream(
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
