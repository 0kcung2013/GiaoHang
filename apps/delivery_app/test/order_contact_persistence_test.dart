import 'package:delivery_app/features/order_contact/models/order_contact_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the durable database message contract', () {
    final message = OrderContactMessage.fromJson({
      'id': 'message-1',
      'order_id': 'order-1',
      'sender_id': 'driver-1',
      'message_type': 'quick_reply',
      'body': 'Tôi đã đến điểm lấy hàng.',
      'client_message_id': 'client-1',
      'created_at': '2026-08-08T02:30:00.000Z',
      'expires_at': '2026-08-22T02:30:00.000Z',
    });

    expect(message.id, 'message-1');
    expect(message.kind, OrderContactMessageKind.quickReply);
    expect(message.clientMessageId, 'client-1');
    expect(message.sentAt, DateTime.utc(2026, 8, 8, 2, 30));
    expect(message.expiresAt, DateTime.utc(2026, 8, 22, 2, 30));
  });

  test('serializes only client-writable columns', () {
    final message = OrderContactMessage.pending(
      orderId: 'order-1',
      senderId: 'customer-1',
      clientMessageId: 'client-1',
      body: 'Tôi xuống ngay ạ.',
      kind: OrderContactMessageKind.text,
      sentAt: DateTime.utc(2026, 8, 8, 2, 30),
    );

    expect(message.toInsertJson(), {
      'order_id': 'order-1',
      'sender_id': 'customer-1',
      'message_type': 'text',
      'body': 'Tôi xuống ngay ạ.',
      'client_message_id': 'client-1',
    });
  });

  test('creates an idempotency key accepted by the database UUID column', () {
    final message = OrderContactMessage.createPending(
      orderId: 'order-1',
      senderId: 'customer-1',
      body: 'Tôi xuống ngay ạ.',
      kind: OrderContactMessageKind.text,
      sentAt: DateTime.utc(2026, 8, 8, 2, 30),
    );

    expect(
      message.clientMessageId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('rejects a malformed database message', () {
    expect(
      () => OrderContactMessage.fromJson({
        'id': 'message-1',
        'order_id': 'order-1',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
