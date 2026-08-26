import 'package:delivery_app/features/order_contact/widgets/order_incoming_message_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'drop on dismiss target hides icon until unread count increases',
    (tester) async {
      await tester.pumpWidget(_harness(unreadCount: 1));

      final button = find.byKey(const Key('test-message-button'));
      final gesture = await tester.startGesture(tester.getCenter(button));
      await gesture.moveBy(const Offset(-20, 80));
      await tester.pump();

      final dismissTarget = find.byKey(
        const Key('order-message-dismiss-target'),
      );
      expect(dismissTarget, findsOneWidget);

      await gesture.moveTo(tester.getCenter(dismissTarget));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(button, findsNothing);

      await tester.pumpWidget(_harness(unreadCount: 2));
      await tester.pumpAndSettle();

      expect(button, findsOneWidget);
    },
  );

  testWidgets('drop outside dismiss target returns icon to its position', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(unreadCount: 1));

    final button = find.byKey(const Key('test-message-button'));
    final initialCenter = tester.getCenter(button);
    final gesture = await tester.startGesture(initialCenter);
    await gesture.moveBy(const Offset(-80, 100));
    await tester.pump();

    expect(
      find.byKey(const Key('order-message-dismiss-target')),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(button, findsOneWidget);
    expect(tester.getCenter(button), initialCenter);
  });
}

Widget _harness({required int unreadCount}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 80,
            right: 20,
            child: OrderIncomingMessageButton(
              buttonKey: const Key('test-message-button'),
              unreadCount: unreadCount,
              onPressed: () {},
              semanticLabel: '$unreadCount tin nhắn mới',
              tooltip: 'Xem tin nhắn mới',
            ),
          ),
        ],
      ),
    ),
  );
}
