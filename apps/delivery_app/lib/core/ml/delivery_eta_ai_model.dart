import 'dart:convert';
import 'dart:typed_data';

import 'delivery_eta_ai_model_data.dart';

/// Local LightGBM inference for the TP.HCM historical traffic model.
///
/// The model is intentionally wrapped by geographic and plausibility guardrails
/// in [DeliveryEtaCalculator].
class DeliveryEtaAiModel {
  DeliveryEtaAiModel._();

  static const int featureCount = 12;
  static const int _nodeSize = 15;
  static final List<_EtaTree> _trees = _decodeTrees();

  static String get version => deliveryEtaAiModelVersion;

  static double predictLogTrafficMultiplier(List<double> features) {
    if (features.length != featureCount ||
        features.any((value) => !value.isFinite)) {
      throw ArgumentError.value(
        features,
        'features',
        'Expected $featureCount finite values.',
      );
    }
    var prediction = 0.0;
    for (final tree in _trees) {
      prediction += tree.predict(features);
    }
    return prediction;
  }

  static List<_EtaTree> _decodeTrees() {
    final bytes = base64Decode(deliveryEtaAiModelPayload);
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 6 ||
        bytes[0] != 0x45 ||
        bytes[1] != 0x54 ||
        bytes[2] != 0x41 ||
        bytes[3] != 0x31) {
      throw const FormatException('Invalid delivery ETA AI model payload.');
    }
    var offset = 4;
    final treeCount = data.getUint16(offset, Endian.little);
    offset += 2;
    final trees = <_EtaTree>[];
    for (var treeIndex = 0; treeIndex < treeCount; treeIndex++) {
      final nodeCount = data.getUint16(offset, Endian.little);
      offset += 2;
      final nodes = <_EtaNode>[];
      for (var nodeIndex = 0; nodeIndex < nodeCount; nodeIndex++) {
        if (offset + _nodeSize > bytes.length) {
          throw const FormatException(
            'Truncated delivery ETA AI model payload.',
          );
        }
        nodes.add(
          _EtaNode(
            feature: data.getInt16(offset, Endian.little),
            thresholdOrLeaf: data.getFloat64(offset + 2, Endian.little),
            left: data.getInt16(offset + 10, Endian.little),
            right: data.getInt16(offset + 12, Endian.little),
            defaultLeft: data.getUint8(offset + 14) == 1,
          ),
        );
        offset += _nodeSize;
      }
      trees.add(_EtaTree(nodes));
    }
    if (offset != bytes.length) {
      throw const FormatException('Unexpected trailing ETA AI model data.');
    }
    return List.unmodifiable(trees);
  }
}

class _EtaTree {
  const _EtaTree(this.nodes);

  final List<_EtaNode> nodes;

  double predict(List<double> features) {
    var nodeIndex = 0;
    while (true) {
      final node = nodes[nodeIndex];
      if (node.feature < 0) return node.thresholdOrLeaf;
      final value = features[node.feature];
      final goLeft = value.isNaN
          ? node.defaultLeft
          : value <= node.thresholdOrLeaf;
      nodeIndex = goLeft ? node.left : node.right;
    }
  }
}

class _EtaNode {
  const _EtaNode({
    required this.feature,
    required this.thresholdOrLeaf,
    required this.left,
    required this.right,
    required this.defaultLeft,
  });

  final int feature;
  final double thresholdOrLeaf;
  final int left;
  final int right;
  final bool defaultLeft;
}
