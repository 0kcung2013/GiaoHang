import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:delivery_app/features/order_contact/models/order_contact_message.dart';
import 'package:delivery_app/features/order_contact/services/order_message_alert_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('incoming chat stays visible across details and map at $size', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = _Transport();
      var opened = 0;
      final now = DateTime.utc(2026, 10, 10);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DriverNavigationView(
              order: OrderModel(
                id: 'order-1',
                customerId: 'customer-1',
                status: 'assigned',
                pickupAddress: 'Điểm lấy',
                pickupLat: 10.7,
                pickupLng: 106.7,
                deliveryAddress: 'Điểm giao',
                deliveryLat: 10.8,
                deliveryLng: 106.8,
                createdAt: now,
                updatedAt: now,
                trackingCode: 'GH-1',
                deliveryFee: 20000,
                serviceType: 'standard',
                paymentMethod: 'cash',
              ),
              map: const SizedBox.expand(),
              arrivedAtTarget: false,
              isUpdatingStatus: false,
              onBack: () {},
              onFitMap: () {},
              onPrimaryAction: () {},
              showOrderDetails: true,
              currentUserId: 'driver-1',
              onOpenMessageChat: () async {
                opened++;
              },
              messageAlertTransport: transport,
            ),
          ),
        ),
      );
      await tester.pump();
      transport.push('message-1');
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('driver-incoming-message-button'));
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('driver-open-map')));
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      transport.push('message-2');
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      expect(transport.connections, 1);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(button, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Transport implements OrderMessageAlertTransport {
  void Function(OrderContactMessage)? onMessage;
  int connections = 0;
  @override
  Future<void> connect({
    required void Function(OrderContactMessage) onMessage,
  }) async {
    connections++;
    this.onMessage = onMessage;
  }

  void push(String id) => onMessage?.call(
    OrderContactMessage(
      id: id,
      orderId: 'order-1',
      senderId: 'customer-1',
      senderRole: OrderContactSenderRole.customer,
      body: 'Tôi đang chờ.',
      sentAt: DateTime.utc(2026, 10, 10),
      kind: OrderContactMessageKind.text,
    ),
  );
  @override
  Future<void> close() async {}
}
