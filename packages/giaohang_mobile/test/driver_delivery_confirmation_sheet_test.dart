import 'dart:convert';

import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/models/driver_delivery_workflow.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_delivery_confirmation_sheet.dart';
import 'package:giaohang_mobile/core/services/delivery_proof_watermark_service.dart';
import 'package:giaohang_mobile/features/order_handoff/data/pickup_handoff_service.dart';
import 'package:giaohang_mobile/features/order_handoff/pickup_handoff_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  for (final amount in [0, 150000]) {
    testWidgets(
      'delivery requires cash confirmation only when collection=$amount',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDriverDeliveryConfirmationSheet(
                    context: context,
                    action: DriverDeliveryAction.confirmDelivery,
                    order: _pickupOrder().copyWith(
                      status: 'delivering',
                      receiverCollectionAmount: amount,
                    ),
                    locationProvider: () => const DeliveryProofLocation(
                      latitude: 10.776,
                      longitude: 106.701,
                    ),
                  ),
                  child: const Text('Mở xác nhận'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Mở xác nhận'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Đã thu'),
          amount == 0 ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Đã giao đúng người nhận hoặc người được ủy quyền'),
          findsOneWidget,
        );
        expect(_confirmButton(tester).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('pickup requires photo, checklist and a four digit customer code', (
    tester,
  ) async {
    DriverDeliveryConfirmationResult? result;
    var attempts = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showDriverDeliveryConfirmationSheet(
                      context: context,
                      action: DriverDeliveryAction.confirmPickup,
                      order: _pickupOrder(),
                      onConfirm: (_) async {
                        attempts++;
                        if (attempts == 1) {
                          throw const PickupHandoffException(
                            PickupHandoffStrings.codeInvalid,
                          );
                        }
                      },
                      locationProvider: () => const DeliveryProofLocation(
                        latitude: 10.773,
                        longitude: 106.703,
                      ),
                      capturePhoto: () async => XFile.fromData(
                        pngBytes,
                        name: 'proof.png',
                        mimeType: 'image/png',
                      ),
                      resolveAddress: (_) async =>
                          '12 Nguyễn Huệ, Quận 1, Hồ Chí Minh',
                      watermarkPhoto:
                          ({
                            required source,
                            required capturedAt,
                            required location,
                            required address,
                          }) async => source,
                    );
                  },
                  child: const Text('Mở xác nhận'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Mở xác nhận'));
    await tester.pumpAndSettle();

    expect(find.text('ẢNH XÁC NHẬN BẮT BUỘC'), findsOneWidget);
    expect(_confirmButton(tester).onPressed, isNull);

    await tester.ensureVisible(find.text('Chạm để chụp ảnh'));
    await tester.tap(find.text('Chạm để chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp lại'), findsOneWidget);
    expect(_confirmButton(tester).onPressed, isNull);

    await tester.ensureVisible(find.text('Đã nhận đúng kiện hàng của đơn này'));
    await tester.tap(find.text('Đã nhận đúng kiện hàng của đơn này'));
    await tester.ensureVisible(
      find.text('Đã kiểm tra loại hàng, kích thước và trọng lượng'),
    );
    await tester.tap(
      find.text('Đã kiểm tra loại hàng, kích thước và trọng lượng'),
    );
    await tester.pump();

    expect(find.textContaining('Đã ứng'), findsNothing);
    expect(_confirmButton(tester).onPressed, isNull);
    await tester.ensureVisible(find.byKey(const Key('pickup-code-input')));
    await tester.enterText(find.byKey(const Key('pickup-code-input')), '0012');
    await tester.pump();
    expect(_confirmButton(tester).onPressed, isNotNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pump();
    await tester.ensureVisible(find.text('Xác nhận nhận hàng'));
    await tester.tap(find.text('Xác nhận nhận hàng'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text(PickupHandoffStrings.codeInvalid), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text ??
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
      '0012',
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Xác nhận nhận hàng'));
    await tester.tap(find.text('Xác nhận nhận hàng'));
    await tester.pumpAndSettle();

    expect(result?.proof?.image, isNotNull);
    expect(result?.pickupCode, '0012');
    expect(attempts, 2);
    expect(result?.proof?.location.latitude, 10.773);
    expect(result?.proof?.address, '12 Nguyễn Huệ, Quận 1, Hồ Chí Minh');
  });
}

FilledButton _confirmButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.byWidgetPredicate((widget) => widget is FilledButton).last,
  );
}

OrderModel _pickupOrder() {
  final now = DateTime(2026, 7, 29, 10);
  return OrderModel(
    id: 'order-proof',
    customerId: 'customer-1',
    driverId: 'driver-1',
    status: 'picking_up',
    pickupAddress: '12 Nguyễn Huệ, Quận 1',
    pickupLat: 10.773,
    pickupLng: 106.703,
    deliveryAddress: '25 Lê Lợi, Quận 1',
    deliveryLat: 10.776,
    deliveryLng: 106.701,
    recipientName: 'Nguyễn Văn A',
    recipientPhone: '0900000000',
    createdAt: now,
    trackingCode: 'GH-PROOF',
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    codCollectionAmount: 120000,
    driverAdvanceAmount: 120000,
    receiverCollectionAmount: 150000,
    updatedAt: now,
  );
}
