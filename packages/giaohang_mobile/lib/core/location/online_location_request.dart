import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'driver_presence_strings.dart';
import 'location_failure.dart';

class OnlineLocationException implements Exception {
  const OnlineLocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A cold browser fix needs a continuous watch, independent of 8s UI reads.
class OnlineLocationRequest {
  OnlineLocationRequest({required this.watch, required this.accepts});

  static const timeout = Duration(seconds: 30);
  static const networkDelay = Duration(seconds: 8);
  final Stream<Position> Function(LocationAccuracy) watch;
  final bool Function(Position) accepts;
  final _result = Completer<Position>();
  final _subscriptions = <StreamSubscription<Position>>[];
  Timer? _deadline;
  Timer? _networkTimer;
  bool _networkStarted = false;
  bool _invalidSample = false;

  Future<Position> start() {
    _deadline = Timer(timeout, () {
      _fail(
        _invalidSample
            ? DriverPresenceStrings.inaccurate
            : DriverPresenceStrings.onlineTimedOut,
      );
    });
    _networkTimer = Timer(networkDelay, _startNetwork);
    _listen(LocationAccuracy.high);
    return _result.future.whenComplete(_cleanup);
  }

  void _startNetwork() {
    if (_result.isCompleted || _networkStarted) return;
    _networkStarted = true;
    _networkTimer?.cancel();
    // Keep the high-accuracy watch alive; either source must satisfy accepts.
    _listen(LocationAccuracy.medium);
  }

  void _listen(LocationAccuracy accuracy) {
    if (_result.isCompleted) return;
    try {
      _subscriptions.add(
        watch(accuracy).listen(
          (position) {
            if (_result.isCompleted) return;
            if (accepts(position)) {
              _result.complete(position);
            } else {
              _invalidSample = true;
            }
          },
          onError: (Object error) {
            if (_result.isCompleted) return;
            final failure = LocationFailure.from(error);
            if (failure == LocationFailure.permissionDenied ||
                failure == LocationFailure.serviceDisabled) {
              _fail(failure.message);
            } else {
              _startNetwork();
            }
          },
          onDone: _startNetwork,
        ),
      );
    } catch (error) {
      final failure = LocationFailure.from(error);
      if (failure == LocationFailure.permissionDenied ||
          failure == LocationFailure.serviceDisabled) {
        _fail(failure.message);
      } else {
        _startNetwork();
      }
    }
  }

  void cancel() => _fail(DriverPresenceStrings.positionUnavailable);

  void _fail(String message) {
    if (!_result.isCompleted) {
      _result.completeError(OnlineLocationException(message));
    }
  }

  void _cleanup() {
    _deadline?.cancel();
    _networkTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}
