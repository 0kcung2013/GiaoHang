import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_navigation_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('moving off-route GPS stays near the camera during animation', (
    tester,
  ) async {
    const route = [LatLng(10.775, 106.680), LatLng(10.785, 106.680)];
    const from = LatLng(10.775, 106.700);
    const to = LatLng(10.77501, 106.700);
    final controller = MapController();
    final order = OrderModel.fromJson({
      'id': 'off-route',
      'customer_id': 'customer',
      'status': 'delivering',
      'pickup_address': 'Pickup',
      'pickup_lat': 10.775,
      'pickup_lng': 106.680,
      'delivery_address': 'Delivery',
      'delivery_lat': 10.785,
      'delivery_lng': 106.680,
      'created_at': '2026-10-14T00:00:00Z',
    });
    Widget map(LatLng position) => MaterialApp(
      home: DriverNavigationMap(
        mapController: controller,
        order: order,
        center: from,
        routePoints: route,
        driverPosition: position,
      ),
    );
    await tester.pumpWidget(map(from));
    await tester.pumpWidget(map(to));
    await tester.pump(const Duration(milliseconds: 250));
    final markers = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers;
    final driver = markers.last.point;
    expect(const Distance().as(LengthUnit.Meter, driver, to), lessThan(5));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
