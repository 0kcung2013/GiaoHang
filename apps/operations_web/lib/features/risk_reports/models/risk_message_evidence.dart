class RiskOrderMessage {
  const RiskOrderMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sentAt,
    required this.isQuickReply,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime sentAt;
  final bool isQuickReply;

  factory RiskOrderMessage.fromJson(Map<String, dynamic> json) {
    return RiskOrderMessage(
      id: json['id'].toString(),
      senderId: json['sender_id'].toString(),
      body: json['body']?.toString() ?? '',
      sentAt: DateTime.parse(json['created_at'].toString()).toLocal(),
      isQuickReply: json['message_type'] == 'quick_reply',
    );
  }
}

class RiskMessageEvidence {
  const RiskMessageEvidence({
    required this.id,
    required this.riskReportId,
    required this.sourceMessageId,
    required this.orderId,
    required this.senderId,
    required this.body,
    required this.sentAt,
    required this.isQuickReply,
    required this.addedBy,
    required this.createdAt,
  });

  final String id;
  final String riskReportId;
  final String? sourceMessageId;
  final String orderId;
  final String senderId;
  final String body;
  final DateTime sentAt;
  final bool isQuickReply;
  final String addedBy;
  final DateTime createdAt;

  factory RiskMessageEvidence.fromJson(Map<String, dynamic> json) {
    return RiskMessageEvidence(
      id: json['id'].toString(),
      riskReportId: json['risk_report_id'].toString(),
      sourceMessageId: json['source_message_id']?.toString(),
      orderId: json['order_id'].toString(),
      senderId: json['sender_id'].toString(),
      body: json['body_snapshot']?.toString() ?? '',
      sentAt: DateTime.parse(json['sent_at_snapshot'].toString()).toLocal(),
      isQuickReply: json['message_type'] == 'quick_reply',
      addedBy: json['added_by'].toString(),
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    );
  }
}

List<RiskOrderMessage> availableRiskOrderMessages({
  required List<RiskOrderMessage> messages,
  required List<RiskMessageEvidence> evidence,
}) {
  final attachedIds = evidence
      .map((item) => item.sourceMessageId)
      .whereType<String>()
      .toSet();
  return messages
      .where((message) => !attachedIds.contains(message.id))
      .toList();
}
