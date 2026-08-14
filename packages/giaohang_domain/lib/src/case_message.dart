enum CaseMessageVisibility {
  public('public'),
  internal('internal');

  const CaseMessageVisibility(this.databaseValue);

  final String databaseValue;

  static CaseMessageVisibility fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => CaseMessageVisibility.public,
  );
}

class CaseMessage {
  const CaseMessage({
    required this.id,
    required this.caseId,
    required this.senderId,
    required this.senderRole,
    required this.visibility,
    required this.body,
    required this.createdAt,
    this.senderName,
  });

  final String id;
  final String caseId;
  final String senderId;
  final String senderRole;
  final CaseMessageVisibility visibility;
  final String body;
  final DateTime createdAt;
  final String? senderName;

  bool get isInternal => visibility == CaseMessageVisibility.internal;

  factory CaseMessage.fromJson(
    Map<String, dynamic> json, {
    required String caseIdKey,
  }) {
    final sender = json['sender'];
    final senderMap = sender is Map
        ? Map<String, dynamic>.from(sender)
        : const <String, dynamic>{};
    return CaseMessage(
      id: json['id']?.toString() ?? '',
      caseId: json[caseIdKey]?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderRole: json['sender_role_snapshot']?.toString() ?? 'unknown',
      visibility: CaseMessageVisibility.fromDatabase(
        json['visibility']?.toString(),
      ),
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      senderName: senderMap['full_name']?.toString(),
    );
  }
}
