import 'package:uuid/uuid.dart';

enum OrderContactSenderRole { customer, driver }

enum OrderContactMessageKind { quickReply, text }

enum OrderContactStage { pickup, delivery, general }

class OrderContactMessage {
  const OrderContactMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    this.senderRole,
    required this.body,
    required this.sentAt,
    required this.kind,
    String? clientMessageId,
    this.expiresAt,
  }) : clientMessageId = clientMessageId ?? id;

  factory OrderContactMessage.pending({
    required String orderId,
    required String senderId,
    required String clientMessageId,
    required String body,
    required DateTime sentAt,
    required OrderContactMessageKind kind,
    OrderContactSenderRole? senderRole,
  }) {
    return OrderContactMessage(
      id: 'pending:$clientMessageId',
      orderId: orderId,
      senderId: senderId,
      senderRole: senderRole,
      body: body,
      sentAt: sentAt,
      kind: kind,
      clientMessageId: clientMessageId,
    );
  }

  factory OrderContactMessage.createPending({
    required String orderId,
    required String senderId,
    required String body,
    required DateTime sentAt,
    required OrderContactMessageKind kind,
    OrderContactSenderRole? senderRole,
  }) {
    return OrderContactMessage.pending(
      orderId: orderId,
      senderId: senderId,
      clientMessageId: const Uuid().v4(),
      body: body,
      sentAt: sentAt,
      kind: kind,
      senderRole: senderRole,
    );
  }

  final String id;
  final String orderId;
  final String senderId;
  final OrderContactSenderRole? senderRole;
  final String body;
  final DateTime sentAt;
  final OrderContactMessageKind kind;
  final String clientMessageId;
  final DateTime? expiresAt;

  factory OrderContactMessage.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isEmpty) throw FormatException('Thiếu trường $key');
      return value;
    }

    final sentAt = DateTime.tryParse(requiredText('created_at'));
    if (sentAt == null) throw const FormatException('created_at không hợp lệ');
    final type = requiredText('message_type');
    final kind = switch (type) {
      'quick_reply' => OrderContactMessageKind.quickReply,
      'text' => OrderContactMessageKind.text,
      _ => throw FormatException('message_type không hợp lệ: $type'),
    };
    final expiresRaw = json['expires_at']?.toString();
    final expiresAt = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
    if (expiresRaw != null && expiresAt == null) {
      throw const FormatException('expires_at không hợp lệ');
    }

    return OrderContactMessage(
      id: requiredText('id'),
      orderId: requiredText('order_id'),
      senderId: requiredText('sender_id'),
      body: requiredText('body'),
      sentAt: sentAt.toUtc(),
      kind: kind,
      clientMessageId: requiredText('client_message_id'),
      expiresAt: expiresAt?.toUtc(),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'order_id': orderId,
    'sender_id': senderId,
    'message_type': kind == OrderContactMessageKind.quickReply
        ? 'quick_reply'
        : 'text',
    'body': body,
    'client_message_id': clientMessageId,
  };

  Map<String, dynamic> toBroadcastPayload() => {
    'id': id,
    'order_id': orderId,
    'sender_id': senderId,
    if (senderRole != null) 'sender_role': senderRole!.name,
    'body': body,
    'sent_at': sentAt.toIso8601String(),
    'kind': kind.name,
  };

  static OrderContactMessage? fromBroadcastPayload(
    Map<String, dynamic> payload,
  ) {
    final id = payload['id']?.toString().trim() ?? '';
    final orderId = payload['order_id']?.toString().trim() ?? '';
    final senderId = payload['sender_id']?.toString().trim() ?? '';
    final body = payload['body']?.toString().trim() ?? '';
    final sentAt = DateTime.tryParse(payload['sent_at']?.toString() ?? '');
    final senderRole = OrderContactSenderRole.values
        .where((value) => value.name == payload['sender_role'])
        .firstOrNull;
    final kind = OrderContactMessageKind.values
        .where((value) => value.name == payload['kind'])
        .firstOrNull;

    if (id.isEmpty ||
        orderId.isEmpty ||
        senderId.isEmpty ||
        body.isEmpty ||
        sentAt == null ||
        senderRole == null ||
        kind == null) {
      return null;
    }

    return OrderContactMessage(
      id: id,
      orderId: orderId,
      senderId: senderId,
      senderRole: senderRole,
      body: body,
      sentAt: sentAt,
      kind: kind,
    );
  }
}

class OrderContactConversation {
  const OrderContactConversation({
    required this.messages,
    required this.canSend,
    this.retentionEndsAt,
  });

  final List<OrderContactMessage> messages;
  final bool canSend;
  final DateTime? retentionEndsAt;
}
