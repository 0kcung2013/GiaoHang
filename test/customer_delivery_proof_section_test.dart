import 'package:customer_app/core/models/delivery_proof_model.dart';
import 'package:customer_app/core/providers/customer_providers.dart';
import 'package:customer_app/features/customer/widgets/delivery_proof/customer_delivery_proof_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer can open pickup and delivery proof photos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final images = [
      _image(DeliveryProofStage.pickup),
      _image(DeliveryProofStage.delivery),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderDeliveryProofsProvider.overrideWith(
            (ref, orderId) async => images,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(375, 812),
                textScaler: TextScaler.linear(1.6),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: CustomerDeliveryProofSection(
                  orderId: 'order-1',
                  orderStatus: 'delivered',
                  imageBuilder: (context, url, semanticLabel, fit) {
                    return ColoredBox(
                      key: Key('$url-${fit.name}'),
                      color: Colors.orange,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ảnh bàn giao'), findsOneWidget);
    expect(find.text('Ảnh nhận hàng'), findsOneWidget);
    expect(find.text('Ảnh giao hàng'), findsOneWidget);
    expect(find.byKey(const Key('https://proof/pickup-cover')), findsOneWidget);
    expect(
      find.byKey(const Key('https://proof/delivery-cover')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ảnh nhận hàng'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(
      find.byKey(const Key('https://proof/pickup-contain')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

DeliveryProofImageModel _image(DeliveryProofStage stage) {
  return DeliveryProofImageModel(
    proof: DeliveryProofModel(
      id: '${stage.value}-proof',
      orderId: 'order-1',
      driverId: 'driver-1',
      stage: stage,
      storagePath: 'driver-1/order-1/${stage.value}',
      capturedAt: DateTime.utc(2026, 7, 30, 12),
    ),
    imageUrl: 'https://proof/${stage.value}',
  );
}
