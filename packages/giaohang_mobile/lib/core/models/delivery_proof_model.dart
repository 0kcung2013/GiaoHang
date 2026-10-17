enum DeliveryProofStage {
  pickup('pickup'),
  delivery('delivery'),
  returnHandoff('return');

  const DeliveryProofStage(this.value);

  final String value;
}

class DeliveryProofModel {
  const DeliveryProofModel({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.stage,
    required this.storagePath,
    required this.capturedAt,
    this.capturedLat,
    this.capturedLng,
  });

  final String id;
  final String orderId;
  final String driverId;
  final DeliveryProofStage stage;
  final String storagePath;
  final DateTime capturedAt;
  final double? capturedLat;
  final double? capturedLng;

  factory DeliveryProofModel.fromJson(Map<String, dynamic> json) {
    return DeliveryProofModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      stage: DeliveryProofStage.values.firstWhere(
        (stage) => stage.value == json['stage']?.toString(),
        orElse: () => DeliveryProofStage.pickup,
      ),
      storagePath: json['storage_path']?.toString() ?? '',
      capturedAt:
          DateTime.tryParse(json['captured_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      capturedLat: (json['captured_lat'] as num?)?.toDouble(),
      capturedLng: (json['captured_lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'driver_id': driverId,
      'stage': stage.value,
      'storage_path': storagePath,
      'captured_at': capturedAt.toIso8601String(),
      'captured_lat': capturedLat,
      'captured_lng': capturedLng,
    };
  }
}

class DeliveryProofImageModel {
  const DeliveryProofImageModel({required this.proof, required this.imageUrl});

  final DeliveryProofModel proof;
  final String imageUrl;
}
