import 'package:delivery_app/features/driver/screens/free_pick/widgets/free_pick_map_canvas.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('shows the 2 km circle whenever driver position is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 375,
          height: 700,
          child: FreePickMapCanvas(
            driverPosition: const LatLng(10.8, 106.7),
            orders: const [],
            searchRadiusMeters: 2000,
            selectedOrderId: null,
            onMapSettled: (_) {},
            onOrderSelected: (_) {},
            onLocate: () {},
            onRadiusIncrease: () {},
            onRadiusDecrease: () {},
            showBaseMap: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final circleLayer = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(circleLayer.circles, hasLength(1));
    expect(circleLayer.circles.single.radius, 2000);
    expect(circleLayer.circles.single.useRadiusInMeter, isTrue);
    expect(find.text('Vùng tự động 2 km'), findsOneWidget);
    expect(find.byTooltip('Về vị trí hiện tại'), findsOneWidget);
    expect(find.byKey(const Key('free-pick-radius-decrease')), findsOneWidget);
    expect(find.byKey(const Key('free-pick-radius-increase')), findsOneWidget);
  });

  testWidgets('expands the circle and disables plus at 4 km', (tester) async {
    var increaseCount = 0;
    var decreaseCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 375,
          height: 700,
          child: FreePickMapCanvas(
            driverPosition: const LatLng(10.8, 106.7),
            orders: const [],
            searchRadiusMeters: 4000,
            selectedOrderId: null,
            onMapSettled: (_) {},
            onOrderSelected: (_) {},
            onLocate: () {},
            onRadiusIncrease: () => increaseCount++,
            onRadiusDecrease: () => decreaseCount++,
            showBaseMap: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final circles = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(circles.circles.map((circle) => circle.radius), [4000, 2000]);
    expect(find.text('FreePick 4 km'), findsOneWidget);

    await tester.tap(find.byKey(const Key('free-pick-radius-increase')));
    await tester.tap(find.byKey(const Key('free-pick-radius-decrease')));
    expect(increaseCount, 0);
    expect(decreaseCount, 1);
  });

  testWidgets('uses exactly two colors for selected and remaining orders', (
    tester,
  ) async {
    final orders = [_order('one', 10.81), _order('two', 10.82)];

    Future<void> pump(String selectedId) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 375,
            height: 700,
            child: FreePickMapCanvas(
              driverPosition: const LatLng(10.78, 106.68),
              orders: orders,
              searchRadiusMeters: 2500,
              selectedOrderId: selectedId,
              onMapSettled: (_) {},
              onOrderSelected: (_) {},
              onLocate: () {},
              onRadiusIncrease: () {},
              onRadiusDecrease: () {},
              showBaseMap: false,
            ),
          ),
        ),
      );
    }

    await pump('one');
    await tester.pumpAndSettle();
    expect(_markerColor(tester, 'one'), AppColors.accent);
    expect(_markerColor(tester, 'two'), AppColors.markerPickup);

    await pump('two');
    await tester.pumpAndSettle();
    expect(_markerColor(tester, 'one'), AppColors.markerPickup);
    expect(_markerColor(tester, 'two'), AppColors.accent);
  });

  testWidgets(
    'shows searchable FreePick orders inside and outside the 2 km circle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 375,
            height: 700,
            child: FreePickMapCanvas(
              driverPosition: const LatLng(10.78, 106.68),
              orders: [_order('near', 10.79), _order('far', 10.81)],
              searchRadiusMeters: 3000,
              selectedOrderId: 'far',
              onMapSettled: (_) {},
              onOrderSelected: (_) {},
              onLocate: () {},
              onRadiusIncrease: () {},
              onRadiusDecrease: () {},
              showBaseMap: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('free-pick-order-marker-near')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('free-pick-order-marker-far')),
        findsOneWidget,
      );
    },
  );
}

Color? _markerColor(WidgetTester tester, String id) {
  final marker = find.byKey(ValueKey('free-pick-order-marker-$id'));
  final container = tester.widget<Container>(
    find.descendant(of: marker, matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

OrderModel _order(String id, double latitude) {
  final now = DateTime(2099);
  return OrderModel(
    id: id,
    customerId: 'customer',
    status: 'confirmed',
    pickupAddress: 'Điểm lấy $id',
    pickupLat: latitude,
    pickupLng: 106.68,
    deliveryAddress: 'Điểm giao $id',
    deliveryLat: latitude + 0.01,
    deliveryLng: 106.69,
    createdAt: now,
    trackingCode: 'GH-DEMO-$id',
    deliveryFee: 18000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    codCollectionAmount: 50000,
    driverNetEarning: 18000,
    driverAdvanceAmount: 50000,
    receiverCollectionAmount: 68000,
    assignmentExpiresAt: now,
    updatedAt: now,
  );
}
