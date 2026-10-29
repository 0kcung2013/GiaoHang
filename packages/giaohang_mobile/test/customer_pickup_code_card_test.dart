import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/features/order_handoff/data/pickup_handoff_service.dart';
import 'package:giaohang_mobile/features/order_handoff/pickup_handoff_strings.dart';
import 'package:giaohang_mobile/features/order_handoff/widgets/customer_pickup_code_card.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1200, 800),
  ]) {
    testWidgets(
      'code is hidden, revealed and expires at $size with 160% text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await _pump(tester, _order(), textScale: 1.6);
        expect(find.text('0012'), findsNothing);
        await tester.ensureVisible(find.text(PickupHandoffStrings.reveal));
        await tester.tap(find.text(PickupHandoffStrings.reveal));
        await tester.pumpAndSettle();
        expect(find.text('0012'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(minutes: 16));
        expect(find.text('0012'), findsNothing);
        expect(find.text(PickupHandoffStrings.expired), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('assignment changes and backgrounding clear visible codes', (
    tester,
  ) async {
    await _pump(tester, _order());
    await tester.tap(find.text(PickupHandoffStrings.reveal));
    await tester.pumpAndSettle();
    expect(find.text('0012'), findsOneWidget);
    await _pump(tester, _order(driverId: 'driver-2'));
    expect(find.text('0012'), findsNothing);
    await tester.tap(find.text(PickupHandoffStrings.reveal));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('0012'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('confirmed handoff shows custody receipt without a code', (
    tester,
  ) async {
    await _pump(
      tester,
      _order().copyWith(actualPickedUpAt: DateTime.utc(2026, 10, 19, 8)),
    );
    expect(find.text(PickupHandoffStrings.confirmed), findsOneWidget);
    expect(find.text(PickupHandoffStrings.reveal), findsNothing);
    expect(find.text(PickupHandoffStrings.receipt), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  OrderModel order, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pickupHandoffServiceProvider.overrideWithValue(_Service())],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CustomerPickupCodeCard(order: order),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

OrderModel _order({String driverId = 'driver'}) => OrderModel(
  id: 'order',
  customerId: 'customer',
  driverId: driverId,
  status: 'picking_up',
  pickupAddress: 'Điểm lấy',
  pickupLat: 10.773,
  pickupLng: 106.703,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.776,
  deliveryLng: 106.701,
  createdAt: DateTime.utc(2026, 10, 19),
  updatedAt: DateTime.utc(2026, 10, 19),
  trackingCode: 'GH-HANDOFF',
  deliveryFee: 0,
  serviceType: 'standard',
  paymentMethod: 'cash',
);

class _Service implements PickupHandoffService {
  @override
  Future<PickupHandoffCode> getCustomerCode(String orderId) async =>
      PickupHandoffCode(
        code: '0012',
        driverId: 'driver',
        serverNow: DateTime.utc(2026, 10, 19, 8),
        expiresAt: DateTime.utc(2026, 10, 19, 8, 15),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
