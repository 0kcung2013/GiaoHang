import 'package:delivery_app/features/order_contact/models/order_contact_message.dart';
import 'package:delivery_app/features/order_contact/services/order_contact_transport.dart';
import 'package:delivery_app/features/order_contact/widgets/order_contact_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('driver can send a large pickup quick reply', (tester) async {
    final transport = _FakeOrderContactTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderContactChatSheet(
            orderId: 'order-1',
            currentUserId: 'driver-1',
            currentRole: OrderContactSenderRole.driver,
            counterpartName: 'Nguyễn Văn An',
            stage: OrderContactStage.pickup,
            transport: transport,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tôi đã đến điểm lấy hàng.'), findsOneWidget);
    await tester.tap(find.text('Tôi đã đến điểm lấy hàng.'));
    await tester.pump();

    expect(transport.sent, hasLength(1));
    expect(transport.sent.single.kind, OrderContactMessageKind.quickReply);
    expect(transport.sent.single.orderId, 'order-1');
  });

  testWidgets('renders an incoming realtime message', (tester) async {
    final transport = _FakeOrderContactTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderContactChatSheet(
            orderId: 'order-1',
            currentUserId: 'customer-1',
            currentRole: OrderContactSenderRole.customer,
            counterpartName: 'Tài xế Minh',
            stage: OrderContactStage.general,
            transport: transport,
          ),
        ),
      ),
    );
    await tester.pump();

    transport.push(
      OrderContactMessage(
        id: 'message-remote',
        orderId: 'order-1',
        senderId: 'driver-1',
        senderRole: OrderContactSenderRole.driver,
        body: 'Tôi đang chờ tại cổng.',
        sentAt: DateTime(2026, 8, 8, 8, 25),
        kind: OrderContactMessageKind.quickReply,
      ),
    );
    await tester.pump();

    expect(find.text('Tôi đang chờ tại cổng.'), findsOneWidget);
    expect(find.text('08:25'), findsOneWidget);
  });

  testWidgets('quick replies fit a small landscape screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(667, 375),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: OrderContactChatSheet(
              orderId: 'order-1',
              currentUserId: 'driver-1',
              currentRole: OrderContactSenderRole.driver,
              counterpartName: 'Nguyễn Văn An',
              stage: OrderContactStage.delivery,
              transport: _FakeOrderContactTransport(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Tôi đã đến điểm giao hàng.'), findsOneWidget);
  });
}

class _FakeOrderContactTransport implements OrderContactTransport {
  final sent = <OrderContactMessage>[];
  void Function(OrderContactMessage message)? _onMessage;

  @override
  Future<OrderContactConversation> loadConversation() async =>
      const OrderContactConversation(messages: [], canSend: true);

  @override
  Future<void> connect({
    required void Function(OrderContactMessage message) onMessage,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    _onMessage = onMessage;
    onConnectionChanged(true);
  }

  void push(OrderContactMessage message) => _onMessage?.call(message);

  @override
  Future<OrderContactMessage> send(OrderContactMessage message) async {
    sent.add(message);
    return message;
  }

  @override
  Future<void> markRead(String messageId) async {}

  @override
  Future<void> close() async {}
}
