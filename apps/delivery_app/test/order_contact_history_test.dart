import 'package:delivery_app/features/order_contact/models/order_contact_message.dart';
import 'package:delivery_app/features/order_contact/services/order_contact_transport.dart';
import 'package:delivery_app/features/order_contact/widgets/order_contact_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads persisted history and marks the latest message read', (
    tester,
  ) async {
    final transport = _HistoryTransport(
      OrderContactConversation(
        canSend: true,
        messages: [
          OrderContactMessage(
            id: 'history-1',
            orderId: 'order-1',
            senderId: 'driver-1',
            senderRole: OrderContactSenderRole.driver,
            body: 'Tin nhắn đã lưu của đơn này.',
            sentAt: DateTime.utc(2026, 8, 8),
            kind: OrderContactMessageKind.text,
            clientMessageId: 'client-history-1',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_testApp(transport));
    await tester.pump();

    expect(find.text('Tin nhắn đã lưu của đơn này.'), findsOneWidget);
    expect(transport.markedReadMessageId, 'history-1');
  });

  testWidgets('terminal order conversation is read-only', (tester) async {
    final transport = _HistoryTransport(
      OrderContactConversation(
        canSend: false,
        retentionEndsAt: DateTime.utc(2026, 8, 22),
        messages: const [],
      ),
    );

    await tester.pumpWidget(_testApp(transport));
    await tester.pump();

    expect(find.text('Đơn đã kết thúc · Chat chỉ đọc'), findsOneWidget);
    expect(find.byKey(const Key('order-contact-message-field')), findsNothing);
  });

  testWidgets(
    'database response and realtime echo do not duplicate a message',
    (tester) async {
      final transport = _RealtimeEchoTransport();
      await tester.pumpWidget(_testApp(transport));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('order-contact-message-field')),
        'Tin nhắn duy nhất',
      );
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pump();

      expect(find.text('Tin nhắn duy nhất'), findsOneWidget);
    },
  );
}

Widget _testApp(OrderContactTransport transport) => MaterialApp(
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
);

class _HistoryTransport implements OrderContactTransport {
  _HistoryTransport(this.conversation);

  final OrderContactConversation conversation;
  String? markedReadMessageId;

  @override
  Future<OrderContactConversation> loadConversation() async => conversation;

  @override
  Future<void> connect({
    required void Function(OrderContactMessage message) onMessage,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    onConnectionChanged(true);
  }

  @override
  Future<OrderContactMessage> send(OrderContactMessage message) async =>
      message;

  @override
  Future<void> markRead(String messageId) async {
    markedReadMessageId = messageId;
  }

  @override
  Future<void> close() async {}
}

class _RealtimeEchoTransport implements OrderContactTransport {
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

  @override
  Future<OrderContactMessage> send(OrderContactMessage message) async {
    final persisted = OrderContactMessage(
      id: 'database-message-1',
      orderId: message.orderId,
      senderId: message.senderId,
      body: message.body,
      sentAt: message.sentAt,
      kind: message.kind,
      clientMessageId: message.clientMessageId,
    );
    _onMessage?.call(persisted);
    return persisted;
  }

  @override
  Future<void> markRead(String messageId) async {}

  @override
  Future<void> close() async {}
}
