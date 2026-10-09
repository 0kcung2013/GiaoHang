import 'dart:async';

import 'package:delivery_app/features/order_contact/models/order_contact_message.dart';
import 'package:delivery_app/features/order_contact/services/order_contact_transport.dart';
import 'package:delivery_app/features/order_contact/widgets/order_contact_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final role in OrderContactSenderRole.values) {
    testWidgets(
      'keeps peer realtime received while ${role.name} history loads',
      (tester) async {
        final transport = _FakeOrderContactTransport()
          ..initialLoad = Completer<OrderContactConversation>();
        await _pumpChat(tester, transport, role: role);
        final peer = _peerMessage(role);
        transport.push(peer);
        transport.initialLoad!.complete(
          const OrderContactConversation(messages: [], canSend: true),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text(peer.body), findsOneWidget);
      },
    );
  }

  testWidgets(
    'sorts a saved own message after a peer event precedes its response',
    (tester) async {
      final transport = _FakeOrderContactTransport()
        ..sendResult = Completer<OrderContactMessage>();
      await _pumpChat(tester, transport);
      await tester.tap(find.text('Tôi đã đến điểm lấy hàng.'));
      await tester.pump();
      final pending = transport.sent.single;
      final serverTime = pending.sentAt.subtract(const Duration(seconds: 10));
      final peer = _peerMessage(
        OrderContactSenderRole.driver,
        sentAt: serverTime.add(const Duration(seconds: 5)),
      );
      transport.push(peer);
      await tester.pump();
      transport.sendResult!.complete(
        OrderContactMessage(
          id: 'saved-own',
          orderId: pending.orderId,
          senderId: pending.senderId,
          body: pending.body,
          sentAt: serverTime,
          kind: pending.kind,
          clientMessageId: pending.clientMessageId,
        ),
      );
      await tester.pump();
      final list = find.byType(ListView).first;
      final ownBubble = find.descendant(
        of: list,
        matching: find.text(pending.body),
      );
      final peerBubble = find.descendant(
        of: list,
        matching: find.text(peer.body),
      );
      expect(
        tester.getTopLeft(ownBubble).dy,
        lessThan(tester.getTopLeft(peerBubble).dy),
      );
    },
  );

  testWidgets('driver catches up persisted customer messages after reconnect', (
    tester,
  ) async {
    final transport = _FakeOrderContactTransport();
    await _pumpChat(tester, transport);
    final peer = _peerMessage(OrderContactSenderRole.driver);
    transport.stored.add(peer);
    transport.connectionChanged!(false);
    transport.connectionChanged!(true);
    await tester.pump();
    await tester.pump();
    expect(find.text(peer.body), findsOneWidget);
  });

  testWidgets(
    'an open driver chat recovers a persisted message missed by realtime',
    (tester) async {
      final transport = _FakeOrderContactTransport();
      await _pumpChat(tester, transport);
      final peer = _peerMessage(OrderContactSenderRole.driver);
      transport.stored.add(peer);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text(peer.body), findsOneWidget);
    },
  );

  testWidgets('keeps a saved realtime echo when the send response is lost', (
    tester,
  ) async {
    final transport = _FakeOrderContactTransport()
      ..sendResult = Completer<OrderContactMessage>();
    await _pumpChat(tester, transport);
    await tester.tap(find.text('Tôi đã đến điểm lấy hàng.'));
    await tester.pump();
    final pending = transport.sent.single;
    final saved = OrderContactMessage(
      id: 'saved-own',
      orderId: pending.orderId,
      senderId: pending.senderId,
      body: pending.body,
      sentAt: pending.sentAt,
      kind: pending.kind,
      clientMessageId: pending.clientMessageId,
    );
    transport.push(saved);
    transport.push(saved);
    transport.stored.add(saved);
    transport.sendResult!.completeError(StateError('HTTP response lost'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(ListView).first,
        matching: find.text(pending.body),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Chưa gửi được tin nhắn. Vui lòng thử lại.'),
      findsNothing,
    );
  });

  testWidgets('stops recovery polling when the chat is closed', (tester) async {
    final transport = _FakeOrderContactTransport();
    await _pumpChat(tester, transport);
    final loads = transport.loads;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 9));
    expect(transport.loads, loads);
  });

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
  final stored = <OrderContactMessage>[];
  Completer<OrderContactConversation>? initialLoad;
  Completer<OrderContactMessage>? sendResult;
  void Function(bool)? connectionChanged;
  int loads = 0;
  void Function(OrderContactMessage message)? _onMessage;

  @override
  Future<OrderContactConversation> loadConversation() async {
    loads++;
    if (loads == 1 && initialLoad != null) return initialLoad!.future;
    return OrderContactConversation(messages: List.of(stored), canSend: true);
  }

  @override
  Future<void> connect({
    required void Function(OrderContactMessage message) onMessage,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    _onMessage = onMessage;
    connectionChanged = onConnectionChanged;
    onConnectionChanged(true);
  }

  void push(OrderContactMessage message) => _onMessage?.call(message);

  @override
  Future<OrderContactMessage> send(OrderContactMessage message) async {
    sent.add(message);
    if (sendResult != null) return sendResult!.future;
    return message;
  }

  @override
  Future<void> markRead(String messageId) async {}

  @override
  Future<void> close() async {}
}

Future<void> _pumpChat(
  WidgetTester tester,
  _FakeOrderContactTransport transport, {
  OrderContactSenderRole role = OrderContactSenderRole.driver,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrderContactChatSheet(
          orderId: 'order-1',
          currentUserId: '${role.name}-1',
          currentRole: role,
          counterpartName: 'Người liên hệ',
          stage: OrderContactStage.pickup,
          transport: transport,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

OrderContactMessage _peerMessage(
  OrderContactSenderRole role, {
  DateTime? sentAt,
}) => OrderContactMessage(
  id: 'peer-message',
  orderId: 'order-1',
  senderId: role == OrderContactSenderRole.driver ? 'customer-1' : 'driver-1',
  body: 'Tin mới của người bên kia',
  sentAt: sentAt ?? DateTime.utc(2026, 10, 8, 14, 53),
  kind: OrderContactMessageKind.text,
);
