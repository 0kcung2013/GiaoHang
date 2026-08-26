import 'package:delivery_app/features/order_contact/models/order_contact_message.dart';
import 'package:delivery_app/features/order_contact/services/order_message_alert_transport.dart';
import 'package:delivery_app/features/order_contact/widgets/order_message_alert_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an incoming driver message while customer stays on home', (
    tester,
  ) async {
    final transport = _FakeOrderMessageAlertTransport();
    OrderMessageAlertOrder? openedOrder;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderMessageAlertListener(
            currentUserId: 'customer-1',
            activeOrders: const [
              OrderMessageAlertOrder(
                orderId: 'order-1',
                trackingCode: 'GH-10107',
                stage: OrderContactStage.pickup,
              ),
            ],
            transport: transport,
            onOpenChat: (order) => openedOrder = order,
            child: const Text('Trang chủ'),
          ),
        ),
      ),
    );
    await tester.pump();

    transport.push(_driverMessage(id: 'message-1', orderId: 'order-1'));
    transport.push(_driverMessage(id: 'message-2', orderId: 'order-1'));
    await tester.pumpAndSettle();

    expect(find.text('Tin nhắn từ tài xế'), findsOneWidget);
    expect(find.text('Tôi đã đến điểm lấy hàng.'), findsOneWidget);
    expect(find.text('Đơn GH-10107'), findsOneWidget);
    expect(find.text('Xem'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-incoming-message-button')),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('customer-incoming-message-button')));
    await tester.pump();

    expect(openedOrder?.orderId, 'order-1');
    expect(
      find.byKey(const Key('customer-incoming-message-button')),
      findsNothing,
    );
  });

  testWidgets('does not alert for own or unrelated order messages', (
    tester,
  ) async {
    final transport = _FakeOrderMessageAlertTransport();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderMessageAlertListener(
            currentUserId: 'customer-1',
            activeOrders: const [
              OrderMessageAlertOrder(
                orderId: 'order-1',
                trackingCode: 'GH-10107',
                stage: OrderContactStage.pickup,
              ),
            ],
            transport: transport,
            onOpenChat: (_) {},
            child: const Text('Trang chủ'),
          ),
        ),
      ),
    );
    await tester.pump();

    transport.push(
      _driverMessage(
        id: 'own-message',
        orderId: 'order-1',
        senderId: 'customer-1',
      ),
    );
    transport.push(_driverMessage(id: 'other-order', orderId: 'order-2'));
    await tester.pump();

    expect(find.text('Tin nhắn từ tài xế'), findsNothing);
    expect(find.text('Tôi đã đến điểm lấy hàng.'), findsNothing);
    expect(
      find.byKey(const Key('customer-incoming-message-button')),
      findsNothing,
    );
  });
}

OrderContactMessage _driverMessage({
  required String id,
  required String orderId,
  String senderId = 'driver-1',
}) {
  return OrderContactMessage(
    id: id,
    orderId: orderId,
    senderId: senderId,
    senderRole: OrderContactSenderRole.driver,
    body: 'Tôi đã đến điểm lấy hàng.',
    sentAt: DateTime.utc(2026, 8, 8),
    kind: OrderContactMessageKind.quickReply,
  );
}

class _FakeOrderMessageAlertTransport implements OrderMessageAlertTransport {
  void Function(OrderContactMessage message)? _onMessage;

  @override
  Future<void> connect({
    required void Function(OrderContactMessage message) onMessage,
  }) async {
    _onMessage = onMessage;
  }

  void push(OrderContactMessage message) => _onMessage?.call(message);

  @override
  Future<void> close() async {}
}
