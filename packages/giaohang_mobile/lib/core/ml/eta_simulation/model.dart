import 'dart:convert';
import 'dart:typed_data';

class EtaCorrectionModel {
  EtaCorrectionModel(this.metadata) {
    final data = ByteData.sublistView(
      base64Decode(metadata['payload'] as String),
    );
    if (data.lengthInBytes < 6 || data.getUint32(0) != 0x45544131) {
      throw const FormatException('INVALID_ETA_MODEL');
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
      throw const FormatException('INVALID_ETA_MODEL_SIZE');
    }
  }
  final Map<String, dynamic> metadata;
  final List<List<_Node>> _trees = [];

  double predict(List<double> vector) {
    if (vector.length != (metadata['feature_names'] as List).length ||
        vector.any((v) => !v.isFinite)) {
      throw ArgumentError('INVALID_ETA_FEATURES');
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
    if (!result.isFinite) throw StateError('INVALID_ETA_PREDICTION');
    return result;
  }

  double multiplier(List<double> vector) => (1 + predict(vector))
      .clamp(
        metadata['minimum_multiplier'] as num,
        metadata['maximum_multiplier'] as num,
      )
      .toDouble();
}

class _Node {
  const _Node(this.feature, this.value, this.left, this.right);
  final int feature, left, right;
  final double value;
}
