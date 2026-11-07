import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import 'physical_gps_policy.dart';
import 'location_failure.dart';

enum DriverPresenceStatus {
  locating,
  ready,
  gpsUnavailable,
  gpsPermissionDenied,
  gpsDisabled,
  gpsTimedOut,
  inaccurate,
  stale,
  syncFailed,
}

/// Idle discovery owns its subscription and only reports ready after a PG ack.
/// Polling continues while stationary, after stream errors, and after timeouts.
class DriverPresenceSession {
  DriverPresenceSession({
    required this.location,
    required this.publish,
    required this.onPosition,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const heartbeat = Duration(seconds: 30);
  static const retryInterval = Duration(seconds: 10);
  static const readyLifetime = Duration(seconds: 90);
  static const requestTimeout = Duration(seconds: 20);

  final LocationService location;
  final Future<bool> Function(Position) publish;
  final void Function(Position) onPosition;
  final DateTime Function() _clock;
  final _changes = StreamController<DriverPresenceStatus>.broadcast();
  final _positions = StreamController<Position>.broadcast();
  DriverPresenceStatus status = DriverPresenceStatus.locating;
  DateTime? syncedAt;
  DateTime? _capturedAt;
  DateTime? _attemptedAt;
  DateTime? _retryAfter;
  Timer? _timer;
  bool _disposed = false;
  bool _sampling = false;
  bool _publishing = false;
  int _healthGeneration = 0;
  int _gpsTimeouts = 0;

  Stream<DriverPresenceStatus> get changes => _changes.stream;
  Stream<Position> get positions => _positions.stream;

  void start() {
    if (_disposed || _timer != null) return;
    _startTracking();
    unawaited(refresh());
    _timer = Timer.periodic(retryInterval, (_) {
      final now = _clock();
      if (syncedAt != null &&
          now.difference(syncedAt!) >= readyLifetime &&
          status == DriverPresenceStatus.ready) {
        _set(DriverPresenceStatus.stale);
      }
      if ((_retryAfter == null || !now.isBefore(_retryAfter!)) &&
          (_attemptedAt == null ||
              now.difference(_attemptedAt!) >= heartbeat ||
              status != DriverPresenceStatus.ready)) {
        unawaited(refresh());
      }
    });
  }

  void _startTracking() {
    if (_disposed || location.isTracking) return;
    try {
      location.startTracking(
        distanceFilterMeters: 10,
        onPosition: (p) => unawaited(_accept(p)),
        onError: (_) {
          if (!_disposed) {
            _healthGeneration++;
            _set(_gpsFailureStatus);
          }
        },
      );
    } catch (_) {
      _set(DriverPresenceStatus.gpsUnavailable);
    }
  }

  /// Also used on lifecycle resume; background retries do not require status UI.
  Future<void> refresh() async {
    if (status == DriverPresenceStatus.ready &&
        syncedAt != null &&
        _clock().difference(syncedAt!) >= readyLifetime) {
      _set(DriverPresenceStatus.stale);
    }
    if (_disposed || _sampling) return;
    _sampling = true;
    try {
      _startTracking();
      final position = await location.getCurrentPosition().timeout(
        requestTimeout,
      );
      if (_disposed) return;
      if (position == null) {
        if (location.lastFailure == LocationFailure.timeout &&
            ++_gpsTimeouts >= 3) {
          // Allow the first fix to warm up; reset a persistently stalled idle watch.
          location.stopTracking();
          _gpsTimeouts = 0;
        }
        _retryAfter = _clock().add(retryInterval);
        _healthGeneration++;
        _set(_gpsFailureStatus);
      } else {
        _gpsTimeouts = 0;
        await _accept(position, retry: true);
      }
    } catch (error) {
      if (!_disposed) {
        _retryAfter = _clock().add(retryInterval);
        _healthGeneration++;
        _set(
          error is TimeoutException
              ? DriverPresenceStatus.gpsTimedOut
              : _gpsFailureStatus,
        );
      }
    } finally {
      _sampling = false;
    }
  }

  DriverPresenceStatus get _gpsFailureStatus => switch (location.lastFailure) {
    LocationFailure.permissionDenied =>
      DriverPresenceStatus.gpsPermissionDenied,
    LocationFailure.serviceDisabled => DriverPresenceStatus.gpsDisabled,
    LocationFailure.timeout => DriverPresenceStatus.gpsTimedOut,
    _ => DriverPresenceStatus.gpsUnavailable,
  };

  Future<void> _accept(Position p, {bool retry = false}) async {
    if (_disposed) return;
    final now = _clock();
    if (_capturedAt != null && p.timestamp.isBefore(_capturedAt!)) {
      return;
    }
    if (!p.latitude.isFinite ||
        !p.longitude.isFinite ||
        p.latitude.abs() > 90 ||
        p.longitude.abs() > 180 ||
        !p.accuracy.isFinite ||
        p.accuracy < 0 ||
        p.accuracy > PhysicalGpsPolicy.onlineAccuracyMeters) {
      _set(DriverPresenceStatus.inaccurate);
      _healthGeneration++;
      return;
    }
    if (!PhysicalGpsPolicy.accepts(
      now: now,
      capturedAt: p.timestamp,
      accuracy: p.accuracy,
      onlinePresence: true,
    )) {
      _set(DriverPresenceStatus.stale);
      _healthGeneration++;
      return;
    }
    _capturedAt = p.timestamp;
    _retryAfter = null;
    onPosition(p);
    _positions.add(p);
    if (_publishing ||
        (!retry &&
            _attemptedAt != null &&
            now.difference(_attemptedAt!) < heartbeat)) {
      return;
    }
    _publishing = true;
    final generation = _healthGeneration;
    _attemptedAt = now;
    try {
      final ok = await publish(p).timeout(requestTimeout);
      if (_disposed || generation != _healthGeneration) return;
      if (ok &&
          PhysicalGpsPolicy.accepts(
            now: _clock(),
            capturedAt: p.timestamp,
            accuracy: p.accuracy,
            onlinePresence: true,
          )) {
        syncedAt = _clock();
        _set(DriverPresenceStatus.ready);
      } else {
        _set(DriverPresenceStatus.syncFailed);
      }
    } catch (_) {
      if (!_disposed) _set(DriverPresenceStatus.syncFailed);
    } finally {
      _publishing = false;
    }
  }

  void _set(DriverPresenceStatus next) {
    if (_disposed || status == next) return;
    status = next;
    _changes.add(next);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    location.stopTracking();
    unawaited(_changes.close());
    unawaited(_positions.close());
  }
}
