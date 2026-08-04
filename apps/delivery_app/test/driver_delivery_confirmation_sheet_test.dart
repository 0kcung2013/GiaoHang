import 'dart:convert';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_delivery_workflow.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_delivery_confirmation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('pickup confirmation requires a captured photo and checklist', (
    tester,
  ) async {
    DriverDeliveryConfirmationResult? result;
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
                      capturePhoto: () async => XFile.fromData(
                        pngBytes,
                        name: 'proof.png',
                        mimeType: 'image/png',
                      ),
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

    await tester.tap(find.text('Chạm để chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp lại'), findsOneWidget);
    expect(_confirmButton(tester).onPressed, isNull);

    await tester.tap(find.text('Đã nhận đúng kiện hàng của đơn này'));
    await tester.tap(
      find.text('Đã kiểm tra tình trạng bên ngoài của kiện hàng'),
    );
    await tester.pump();

    expect(_confirmButton(tester).onPressed, isNotNull);
    await tester.ensureVisible(find.text('Đã nhận hàng'));
    await tester.tap(find.text('Đã nhận hàng'));
    await tester.pumpAndSettle();

    expect(result?.proofImage, isNotNull);
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
    updatedAt: now,
  );
}
