import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../location/physical_gps_policy.dart';
import '../location/driver_presence_strings.dart';
import '../location/location_failure.dart';
import '../location/online_location_request.dart';

class LocationService {
  LocationService({bool? isWeb}) : _isWeb = isWeb ?? kIsWeb;

  static const acquisitionTimeout = Duration(seconds: 8);
  static const cacheLifetime = Duration(seconds: 5);
  final bool _isWeb;
  final _updates = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _acquisitionSubscription;
  Future<Position?>? _acquisition;
  Future<Position>? _onlineAcquisition;
  OnlineLocationRequest? _onlineRequest;
  Position? _latest;
  bool _disposed = false;
  int _acquisitionGeneration = 0;
  LocationFailure? lastFailure;

  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  int _trackingGeneration = 0;

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

  Future<Position?> getCurrentPosition() {
    if (_disposed) return Future.value(null);
    if (_acquisition != null) return _acquisition!;
    final latest = _recentPosition;
    if (latest != null) {
      return Future.value(latest);
    }
    final request = _acquire();
    _acquisition = request;
    unawaited(
      request.then((_) {
        if (identical(_acquisition, request)) _acquisition = null;
      }),
    );
    return request;
  }

  Position? get _recentPosition {
    final latest = _latest;
    if (lastFailure != null || latest == null) return null;
    final age = DateTime.now().difference(latest.timestamp);
    return !age.isNegative && age <= cacheLifetime ? latest : null;
  }

  Future<Position?> _acquire() async {
    final generation = ++_acquisitionGeneration;
    try {
      final position = await _readDevicePosition(
        generation,
      ).timeout(acquisitionTimeout);
      if (_disposed) return null;
      _latest = position;
      lastFailure = null;
      return position;
    } catch (e) {
      lastFailure = LocationFailure.from(e);
      debugPrint('[GPS] getCurrentPosition error: $e');
      return null;
    } finally {
      if (generation == _acquisitionGeneration) {
        _acquisitionGeneration++;
        unawaited(_acquisitionSubscription?.cancel());
        _acquisitionSubscription = null;
      }
    }
  }

  Future<Position> _readDevicePosition(int generation) async {
    if (!_isWeb) {
      if (!await requestPermission()) {
        throw const PermissionDeniedException('Location permission denied');
      }
      if (generation != _acquisitionGeneration || _disposed) {
        throw TimeoutException('Location acquisition expired');
      }
      final latest = _recentPosition;
      if (latest != null) return latest;
      if (_isTracking) return _readFromStream(_updates.stream);
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: acquisitionTimeout,
        ),
      );
    }
    // geolocator_web 4.1.4 passes Duration.inMicroseconds to browser milliseconds.
    // Use a cancellable watch with a Dart deadline, also covering permission UI.
    // Reuse the running watch's next capture; never stack one-shot GPS requests.
    final source = _isTracking
        ? _updates.stream
        : Geolocator.getPositionStream(
            locationSettings: WebSettings(
              accuracy: LocationAccuracy.high,
              maximumAge: cacheLifetime,
            ),
          );
    return _readFromStream(source);
  }

  Future<Position> _readFromStream(Stream<Position> source) {
    final result = Completer<Position>();
    _acquisitionSubscription = source.listen(
      (p) {
        if (!result.isCompleted) result.complete(p);
      },
      onError: (Object error) {
        if (!result.isCompleted) result.completeError(error);
      },
      onDone: () {
        if (!result.isCompleted) {
          result.completeError(
            const PositionUpdateException('Location source stopped'),
          );
        }
      },
    );
    return result.future;
  }

  /// Acquire at PIN submission time, not before the PIN sheet was opened.
  Future<Position> getOnlinePosition() {
    final pending = _onlineAcquisition;
    if (pending != null) return pending;
    final request = _acquireOnlinePosition();
    _onlineAcquisition = request;
    void clear() {
      if (identical(_onlineAcquisition, request)) _onlineAcquisition = null;
    }

    unawaited(
      request.then<void>((_) => clear(), onError: (Object _) => clear()),
    );
    return request;
  }

  Future<Position> _acquireOnlinePosition() async {
    if (_disposed) {
      throw const OnlineLocationException(
        DriverPresenceStrings.positionUnavailable,
      );
    }
    if (_isWeb) {
      final recent = _recentPosition;
      if (recent != null && _acceptsOnlinePosition(recent)) return recent;
      final request = OnlineLocationRequest(
        watch: (accuracy) => accuracy == LocationAccuracy.high && _isTracking
            ? _updates.stream
            : Geolocator.getPositionStream(
                locationSettings: WebSettings(
                  accuracy: accuracy,
                  maximumAge: cacheLifetime,
                ),
              ),
        accepts: _acceptsOnlinePosition,
      );
      _onlineRequest = request;
      try {
        final position = await request.start();
        _latest = position;
        lastFailure = null;
        return position;
      } finally {
        if (identical(_onlineRequest, request)) _onlineRequest = null;
      }
    }
    final position = await getCurrentPosition().timeout(
      acquisitionTimeout,
      onTimeout: () => throw const OnlineLocationException(
        DriverPresenceStrings.onlineTimedOut,
      ),
    );
    if (position == null) {
      throw OnlineLocationException(
        lastFailure?.message ?? DriverPresenceStrings.gpsUnavailable,
      );
    }
    if (!_acceptsOnlinePosition(position)) {
      throw const OnlineLocationException(DriverPresenceStrings.inaccurate);
    }
    return position;
  }

  bool _acceptsOnlinePosition(Position position) =>
      PhysicalGpsPolicy.accepts(
        now: DateTime.now(),
        capturedAt: position.timestamp,
        accuracy: position.accuracy,
        onlinePresence: true,
      ) &&
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      position.latitude.abs() <= 90 &&
      position.longitude.abs() <= 180;

  void startTracking({
    required void Function(Position position) onPosition,
    void Function(String error)? onError,
    int distanceFilterMeters = 10,
  }) {
    if (_disposed || _isTracking) return;
    _positionStream?.cancel();
    _isTracking = true;
    final generation = ++_trackingGeneration;

    try {
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: distanceFilterMeters,
            ),
          ).listen(
            (position) {
              if (!_isTracking || generation != _trackingGeneration) return;
              _latest = position;
              lastFailure = null;
              _updates.add(position);
              onPosition(position);
            },
            onError: (error) {
              if (generation != _trackingGeneration) return;
              _isTracking = false;
              lastFailure = LocationFailure.from(error);
              _updates.addError(error);
              onError?.call(error.toString());
            },
            onDone: () {
              if (generation == _trackingGeneration) _isTracking = false;
            },
          );
    } catch (error) {
      _isTracking = false;
      lastFailure = LocationFailure.from(error);
      _updates.addError(error);
      onError?.call(error.toString());
    }
  }

  void stopTracking() {
    _trackingGeneration++;
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onlineRequest?.cancel();
    _acquisitionGeneration++;
    unawaited(_acquisitionSubscription?.cancel());
    _latest = null;
    stopTracking();
    unawaited(_updates.close());
  }
}
