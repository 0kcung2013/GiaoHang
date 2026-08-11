import 'package:delivery_app/features/order_contact/models/order_contact_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a valid contact broadcast payload', () {
    final sentAt = DateTime.utc(2026, 8, 8, 2, 30);
    final message = OrderContactMessage(
      id: 'message-1',
      orderId: 'order-1',
      senderId: 'driver-1',
      senderRole: OrderContactSenderRole.driver,
      body: 'Tôi đã đến điểm lấy hàng.',
      sentAt: sentAt,
      kind: OrderContactMessageKind.quickReply,
    );

    final parsed = OrderContactMessage.fromBroadcastPayload(
      message.toBroadcastPayload(),
    );

    expect(parsed, isNotNull);
    expect(parsed!.id, message.id);
    expect(parsed.orderId, message.orderId);
    expect(parsed.senderRole, OrderContactSenderRole.driver);
    expect(parsed.kind, OrderContactMessageKind.quickReply);
    expect(parsed.body, message.body);
    expect(parsed.sentAt, sentAt);
  });

  test('rejects malformed broadcast payloads', () {
    expect(
      OrderContactMessage.fromBroadcastPayload({
        'id': 'message-1',
        'order_id': 'order-1',
      }),
      isNull,
    );
  });
}
