import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

final _indexes = Expando<RoadNodeIndex>();

class RoadNodeIndex {
  RoadNodeIndex(Map<String, dynamic> context) {
    final road = context['speed_roads'] as Map?;
    final bytes = road == null
        ? Uint8List(0)
        : base64Decode(road['payload'] as String);
    ids = Float64List((road?['node_count'] as num?)?.toInt() ?? 0);
    values = Uint8List(ids.length);
    var offset = 0, previous = 0;
    int take() {
      var delta = 0, factor = 1, byte = 0;
      do {
        byte = bytes[offset++];
        delta += (byte & 127) * factor;
        factor *= 128;
      } while (byte & 128 != 0);
      return delta;
    }

    for (var i = 0; i < ids.length;) {
      final v4 = road?['encoding'] == 'attribute_optional_delta_run_v4';
      final head = v4 ? bytes[offset++] : 0;
      final start = previous + (v4 ? ((head & 64 != 0) ? take() : 1) : take());
      final v3 = road?['encoding'] == 'delta_attribute_optional_run_v3';
      final oldCount =
          road?['encoding'] == 'delta_varint_run_count_attribute_v2'
          ? take()
          : 1;
      final attribute = v4 ? head : bytes[offset++];
      final count = (v3 || v4) && (attribute & 128 != 0) ? take() : oldCount;
      final value = (v3 || v4) ? attribute & 63 : attribute;
      if (count < 1 || i + count > ids.length) {
        throw const FormatException('INVALID_SPEED_ROAD_INDEX');
      }
      for (var n = 0; n < count; n++, i++) {
        ids[i] = (start + n).toDouble();
        values[i] = value;
      }
      previous = start + count - 1;
    }
    if (offset != bytes.length) {
      throw const FormatException('INVALID_SPEED_ROAD_INDEX');
    }
  }
  late final Float64List ids;
  late final Uint8List values;
  int? get(num? id) {
    if (id == null) return null;
    var low = 0, high = ids.length - 1;
    while (low <= high) {
      final middle = (low + high) ~/ 2, value = ids[middle];
      if (value == id) return values[middle];
      if (value < id) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return null;
  }
}

RoadNodeIndex roadIndex(Map<String, dynamic> context) =>
    _indexes[context] ??= RoadNodeIndex(context);

List<double> trafficClock(String at) {
  final wall = DateTime.parse(at).toUtc().add(const Duration(hours: 7));
  final hour = wall.hour + (wall.minute ~/ 15) / 4;
  final weekend = wall.weekday >= 6 ? 1.0 : 0.0;
  final peak =
      math.max(
        math.exp(-.5 * math.pow((hour - 7.8) / 1.05, 2)),
        math.exp(-.5 * math.pow((hour - 17.5) / 1.25, 2)),
      ) *
      (weekend == 1 ? .65 : 1);
  return [(peak * 1e6).round() / 1e6, weekend];
}

List<double> roadFeatures(
  int? first,
  int? second,
  int fallbackClass,
  List<double> clock,
) {
  final found = [first, second].whereType<int>().toList();
  final kind = found.isEmpty
      ? fallbackClass
      : found.map((v) => v & 3).reduce(math.min);
  final bend = found.isEmpty
      ? 0.0
      : found.map((v) => (v >> 2) & 3).reduce(math.max) / 3;
  final junction = found.isEmpty
      ? 0.0
      : found.fold(0, (s, v) => s + ((v >> 4) & 1)) / found.length;
  final signal = found.isEmpty
      ? 0
      : found.map((v) => (v >> 5) & 1).reduce(math.max);
  return [
    kind.toDouble(),
    (bend * 1e6).round() / 1e6,
    junction,
    signal.toDouble(),
    ...clock,
  ];
}
