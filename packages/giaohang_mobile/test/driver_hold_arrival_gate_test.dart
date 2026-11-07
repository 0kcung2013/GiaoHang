import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/data/driver_delivery_arrival_repository.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_navigation_view.dart';

Map<String, dynamic> snapshot(bool confirmed) => {
  'delivery_arrived_at': confirmed
      ? DateTime.now().toUtc().toIso8601String()
      : null,
  'server_now': DateTime.now().toUtc().toIso8601String(),
  'can_report_recipient': false,
};
OrderModel order() => OrderModel(
  id: 'order',
  customerId: 'customer',
  status: 'delivering',
  pickupAddress: 'Điểm lấy',
  pickupLat: 10.78,
  pickupLng: 106.7,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.79,
  deliveryLng: 106.71,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  trackingCode: 'GH-TEST',
  deliveryFee: 18000,
  serviceType: 'standard',
  paymentMethod: 'cash',
);
Widget view(
  DriverDeliveryArrivalRepository repository,
  VoidCallback onHold, {
  bool near = true,
}) => MaterialApp(
  home: DriverNavigationView(
    order: order(),
    map: const SizedBox.expand(),
    arrivedAtTarget: near,
    isUpdatingStatus: false,
    onBack: () {},
    onFitMap: () {},
    onPrimaryAction: () {},
    onPrepareDeliveryArrival: () async {},
    deliveryArrivalRepository: repository,
    onHoldOrder: onHold,
  ),
);
void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'GPS near hides hold until the arrival swipe succeeds on server',
    (tester) async {
      final confirmation = Completer<Map<String, dynamic>>();
      var confirms = 0;
      var holds = 0;
      final repo = DriverDeliveryArrivalRepository(
        invoke: (name, params) async {
          if (name == 'confirm_driver_delivery_arrival') {
            confirms++;
            return confirmation.future;
          }
          return snapshot(false);
        },
      );
      await tester.pumpWidget(view(repo, () => holds++));
      await tester.pumpAndSettle();
      expect(find.text('Giữ đơn'), findsNothing);
      final swipe = find.byKey(const Key('driver-navigation-primary-action'));
      await tester.drag(swipe, const Offset(600, 0));
      await tester.pump();
      expect(confirms, 1);
      expect(find.text('Giữ đơn'), findsNothing);
      confirmation.complete(snapshot(true));
      await tester.pumpAndSettle();
      expect(find.text('Giữ đơn'), findsOneWidget);
      await tester.tap(find.text('Giữ đơn'));
      expect(holds, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed arrival confirmation does not expose hold', (
    tester,
  ) async {
    final repo = DriverDeliveryArrivalRepository(
      invoke: (name, params) async {
        if (name == 'confirm_driver_delivery_arrival') {
          throw StateError('offline');
        }
        return snapshot(false);
      },
    );
    await tester.pumpWidget(view(repo, () {}));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('driver-navigation-primary-action')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Giữ đơn'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'confirmed arrival survives remount but leaving geofence hides hold',
    (tester) async {
      final repo = DriverDeliveryArrivalRepository(
        invoke: (_, _) async => snapshot(true),
      );
      for (final near in [true, true, false]) {
        await tester.pumpWidget(view(repo, () {}, near: near));
        await tester.pumpAndSettle();
        expect(find.text('Giữ đơn'), near ? findsOneWidget : findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
