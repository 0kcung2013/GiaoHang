import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/constants/app_theme.dart';
import 'package:customer_app/core/models/order_model.dart';
import 'package:customer_app/features/customer/screens/order/widgets/order_card.dart';
import 'package:customer_app/features/customer/screens/order/widgets/order_card_content.dart';
import 'package:customer_app/features/customer/screens/order/widgets/order_card_image.dart';
import 'package:customer_app/features/customer/screens/order/widgets/order_card_route_panel.dart';

void main() {
  testWidgets('customer order card uses a white orange cargo-first layout', (
    tester,
  ) async {
    var tapped = false;
    final order = _order();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: OrderCard(
              order: order,
              isFeatured: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    final surface = tester.widget<DecoratedBox>(
      find.byKey(orderCardSurfaceKey),
    );
    final decoration = surface.decoration as BoxDecoration;

    expect(decoration.color, AppColors.bgCard);
    expect(decoration.color, isNot(AppColors.primary));
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
    expect(find.byKey(orderCardStatusRailKey), findsOneWidget);
    expect(find.byKey(orderCardImagePlaceholderKey), findsOneWidget);
    expect(find.byKey(orderCardRoutePanelKey), findsOneWidget);
    expect(find.text('Bánh kem sinh nhật'), findsOneWidget);
    expect(find.text('ĐỒ ĂN'), findsOneWidget);
    expect(find.text('85.000đ'), findsOneWidget);
    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
    expect(
      find.textContaining('12 Nguyễn Trãi', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('58 Lê Lợi', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Chi tiết'), findsNothing);

    await tester.tap(find.byKey(orderCardDetailAffordanceKey));
    expect(tapped, isTrue);
  });

  testWidgets('customer order card renders the uploaded cargo image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: OrderCard(
              order: _order(
                itemImageUrl: 'https://example.com/order-cargo.jpg',
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(orderCardImageKey), findsOneWidget);
  });

  testWidgets('customer order card fits a small phone with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            backgroundColor: AppColors.bgLight,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: OrderCard(order: _order(), onTap: () {}),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(orderCardRoutePanelKey), findsOneWidget);
    expect(find.byKey(orderCardDetailAffordanceKey), findsOneWidget);
  });
}

OrderModel _order({String? itemImageUrl}) {
  final now = DateTime.now();
  return OrderModel(
    id: 'order-12345678',
    customerId: 'customer-1',
    status: 'delivering',
    pickupAddress: '12 Nguyễn Trãi, Quận 1',
    pickupLat: 10.76,
    pickupLng: 106.66,
    deliveryAddress: '58 Lê Lợi, Quận 3',
    deliveryLat: 10.78,
    deliveryLng: 106.68,
    totalPrice: 85000,
    createdAt: now.subtract(const Duration(minutes: 8)),
    trackingCode: 'GH-2026-001',
    recipientName: 'Nguyễn Minh Anh',
    itemName: 'Bánh kem sinh nhật',
    itemCategory: 'food',
    itemDescription: 'Giữ hộp thẳng và giao nhẹ tay',
    itemImageUrl: itemImageUrl,
    deliveryFee: 85000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
