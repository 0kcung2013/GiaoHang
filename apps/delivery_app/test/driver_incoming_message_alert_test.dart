import 'package:delivery_app/features/order_contact/models/order_contact_message.dart';
import 'package:delivery_app/features/order_contact/services/order_message_alert_transport.dart';
import 'package:delivery_app/features/order_contact/widgets/driver_incoming_message_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows unread badge and clears it after opening chat', (
    tester,
  ) async {
    final transport = _FakeOrderMessageAlertTransport();
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: DriverIncomingMessageAlert(
              orderId: 'order-1',
              currentUserId: 'driver-1',
              transport: transport,
              onOpenChat: () async => openCount++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('driver-incoming-message-button')),
      findsNothing,
    );

    transport.push(_customerMessage(id: 'message-1'));
    await tester.pump();

    expect(
      find.byKey(const Key('driver-incoming-message-button')),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);

    transport.push(_customerMessage(id: 'message-2'));
    await tester.pump();

    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('driver-incoming-message-button')));
    await tester.pumpAndSettle();

    expect(openCount, 1);
    expect(
      find.byKey(const Key('driver-incoming-message-button')),
      findsNothing,
    );
  });

  testWidgets('ignores own, unrelated, and duplicate messages', (tester) async {
    final transport = _FakeOrderMessageAlertTransport();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverIncomingMessageAlert(
            orderId: 'order-1',
            currentUserId: 'driver-1',
            transport: transport,
            onOpenChat: () async {},
          ),
        ),
      ),
    );
    await tester.pump();

    transport.push(_customerMessage(id: 'own', senderId: 'driver-1'));
    transport.push(_customerMessage(id: 'other-order', orderId: 'order-2'));
    transport.push(_customerMessage(id: 'message-1'));
    transport.push(_customerMessage(id: 'message-1'));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });
}

OrderContactMessage _customerMessage({
  required String id,
  String orderId = 'order-1',
  String senderId = 'customer-1',
}) {
  return OrderContactMessage(
    id: id,
    orderId: orderId,
    senderId: senderId,
    senderRole: OrderContactSenderRole.customer,
    body: 'Tôi đang chờ.',
    sentAt: DateTime.utc(2026, 8, 25, 8, 25),
    kind: OrderContactMessageKind.text,
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
