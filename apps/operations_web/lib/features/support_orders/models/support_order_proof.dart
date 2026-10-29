/// Read projection of a delivery proof, keeping its private storage reference.
class SupportOrderProof {
  const SupportOrderProof({
    required this.stage,
    required this.storagePath,
    required this.capturedAt,
  });

  final String stage;
  final String storagePath;
  final DateTime capturedAt;

  factory SupportOrderProof.fromJson(Map<String, dynamic> json) =>
      SupportOrderProof(
        stage: json['stage'] as String,
        storagePath: json['storage_path'] as String,
        capturedAt: DateTime.parse(json['captured_at'] as String).toLocal(),
      );
}
