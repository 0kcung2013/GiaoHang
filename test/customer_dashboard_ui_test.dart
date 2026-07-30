import 'package:customer_app/core/models/order_model.dart';
import 'package:customer_app/core/providers/customer_providers.dart';
import 'package:customer_app/features/customer/screens/dashboard/dashboard_strings.dart';
import 'package:customer_app/features/customer/screens/dashboard/widgets/dashboard_create_delivery_hero.dart';
import 'package:customer_app/features/customer/screens/dashboard/widgets/dashboard_hero.dart';
import 'package:customer_app/features/customer/screens/dashboard/widgets/dashboard_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer dashboard content fits a small phone', (tester) async {
    await _setTestViewport(tester, const Size(375, 900));

    await tester.pumpWidget(
      const _DashboardPreview(textScaler: TextScaler.noScaling),
    );
    await tester.pumpAndSettle();

    expect(find.text(DashboardStrings.heroTitle), findsOneWidget);
    expect(find.text(DashboardStrings.createDelivery), findsOneWidget);
    expect(find.text(DashboardStrings.pickupPrompt), findsOneWidget);
    expect(find.text(DashboardStrings.deliveryPrompt), findsOneWidget);
    expect(find.text(DashboardStrings.servicePromiseTitle), findsNothing);
    expect(find.text('Giao gần đây'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DashboardCreateDeliveryHero),
        matching: find.byWidgetPredicate((widget) {
          return widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient != null;
        }),
      ),
      findsNothing,
      reason: 'customer hero should use one continuous cream background',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('active delivery card stays compact on the customer home', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 900));
    final order = _activeOrder();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assignedDriverProvider.overrideWith((ref, orderId) async => null),
        ],
        child: _SectionPreview(
          textScaler: TextScaler.linear(1.6),
          child: DashboardActiveDeliveryCard(activeOrders: [order]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đang chờ xác nhận'), findsOneWidget);
    expect(find.text(order.pickupAddress), findsOneWidget);
    expect(find.text(order.deliveryAddress), findsOneWidget);
    expect(find.text('Theo dõi trực tiếp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard sections support large accessible text', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 900));

    await tester.pumpWidget(
      const _SectionPreview(
        textScaler: TextScaler.linear(1.6),
        child: DashboardCreateDeliveryHero(isFirstDelivery: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'hero must not overflow');

    await tester.pumpWidget(
      const _SectionPreview(
        textScaler: TextScaler.linear(1.6),
        child: DashboardQuickActions(hasActiveDelivery: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(DashboardStrings.createOrder), findsOneWidget);
    expect(find.text(DashboardStrings.trackOrder), findsOneWidget);
    expect(find.text(DashboardStrings.orderHistory), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'quick actions must not overflow',
    );
  });
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _DashboardPreview extends StatelessWidget {
  const _DashboardPreview({required this.textScaler});

  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: textScaler),
            child: const Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardCreateDeliveryHero(isFirstDelivery: true),
                      SizedBox(height: 24),
                      DashboardQuickActions(hasActiveDelivery: true),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionPreview extends StatelessWidget {
  const _SectionPreview({required this.textScaler, required this.child});

  final TextScaler textScaler;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

OrderModel _activeOrder() {
  final now = DateTime.now();
  return OrderModel(
    id: 'order-12345678',
    customerId: 'customer-1',
    status: 'pending',
    pickupAddress: 'Cổng sau, Hiệp An 2, Phường Phú An',
    pickupLat: 10.98,
    pickupLng: 106.67,
    deliveryAddress: '123 Tân An 6, Phường Phú An',
    deliveryLat: 10.99,
    deliveryLng: 106.69,
    totalPrice: 45000,
    createdAt: now,
    trackingCode: 'GH-10082',
    deliveryFee: 45000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
