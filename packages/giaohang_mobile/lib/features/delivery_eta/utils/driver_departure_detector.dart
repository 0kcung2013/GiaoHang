import 'package:latlong2/latlong.dart';

/// Only fresh, accurate, consecutive fixes can end preparation early.
/// Coordinates stay in memory and are never added to the ETA snapshot.
class DriverDepartureDetector {
  LatLng? _previous;
  LatLng? _start;
  DateTime? _previousAt;
  DateTime? _startedAt;
  int _movingFixes = 0;
  bool departed = false;
  bool add(
    LatLng position,
    DateTime at, {
    double accuracyMeters = 0,
    DateTime? now,
  }) {
    if (departed) return true;
    final age = (now ?? at).difference(at);
    if (accuracyMeters > 50 ||
        age > const Duration(seconds: 15) ||
        age < const Duration(seconds: -5)) {
      return false;
    }
    final previous = _previous;
    if (previous == null) {
      _reset(position, at);
      return false;
    }
    final elapsed = at.difference(_previousAt!);
    if (elapsed < const Duration(seconds: 1)) return false;
    final step = const Distance().as(LengthUnit.Meter, previous, position);
    if (elapsed > const Duration(seconds: 60) ||
        step > 250 ||
        step / (elapsed.inMilliseconds / 1000) > 33.3) {
      _reset(position, at);
      return false;
    }
    _previous = position;
    _previousAt = at;
    if (step >= 5) {
      _movingFixes++;
    } else {
      _reset(position, at);
      return false;
    }
    final total = const Distance().as(LengthUnit.Meter, _start!, position);
    departed =
        _movingFixes >= 3 &&
        total >= 30 &&
        at.difference(_startedAt!) >= const Duration(seconds: 3);
    return departed;
  }

  void _reset(LatLng position, DateTime at) {
    _previous = _start = position;
    _previousAt = _startedAt = at;
    _movingFixes = 0;
  }
}
