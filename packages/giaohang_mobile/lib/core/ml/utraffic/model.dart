import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Research artifact loader. It does not replace the Delivery App model.
class SpeedModel {
  SpeedModel(this.metadata) {
    final data = ByteData.sublistView(
      base64Decode(metadata['payload'] as String),
    );
    if (data.lengthInBytes < 6 || data.getUint32(0) != 0x45544131) {
      throw const FormatException('INVALID_MODEL');
    }
    var offset = 6;
    for (var t = 0; t < data.getUint16(4, Endian.little); t++) {
      final count = data.getUint16(offset, Endian.little);
      offset += 2;
      final nodes = <_Node>[];
      for (var n = 0; n < count; n++, offset += 15) {
        nodes.add(
          _Node(
            data.getInt16(offset, Endian.little),
            data.getFloat64(offset + 2, Endian.little),
            data.getInt16(offset + 10, Endian.little),
            data.getInt16(offset + 12, Endian.little),
          ),
        );
      }
      _trees.add(nodes);
    }
    if (offset != data.lengthInBytes) {
      throw const FormatException('INVALID_MODEL_SIZE');
    }
  }
  final Map<String, dynamic> metadata;
  final List<List<_Node>> _trees = [];

  List<double> featuresAt(Map<String, num> road, String at) {
    final wall = DateTime.parse(at).toUtc().add(const Duration(hours: 7));
    final hour = wall.hour + wall.minute / 60;
    final weekday = wall.weekday - 1;
    final values = <String, num>{
      ...road,
      'hour': hour,
      'weekday': weekday,
      'weekend': weekday >= 5 ? 1 : 0,
      'hour_sin': math.sin(hour * 2 * math.pi / 24),
      'hour_cos': math.cos(hour * 2 * math.pi / 24),
    };
    return [
      for (final name in metadata['feature_names'] as List)
        values[name]!.toDouble(),
    ];
  }

  double predict(List<double> vector) {
    if (vector.length != (metadata['feature_names'] as List).length ||
        vector.any((v) => !v.isFinite)) {
      throw ArgumentError('INVALID_MODEL_FEATURES');
    }
    var result = 0.0;
    for (final nodes in _trees) {
      var node = nodes.first;
      while (node.feature >= 0) {
        node =
            nodes[vector[node.feature] <= node.value ? node.left : node.right];
      }
      result += node.value;
    }
    if (metadata['target'] == 'log1p') result = math.exp(result) - 1;
    if (!result.isFinite) throw StateError('INVALID_MODEL_SPEED');
    return result
        .clamp(
          metadata['minimum_speed_kmh'] as num,
          metadata['maximum_speed_kmh'] as num,
        )
        .toDouble();
  }

  double speedAt(Map<String, num> road, String at) =>
      predict(featuresAt(road, at));
}

class _Node {
  const _Node(this.feature, this.value, this.left, this.right);
  final int feature, left, right;
  final double value;
}
