import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/widgets/delivery_traffic_map_layer.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const route = [
    LatLng(10.7750, 106.6800),
    LatLng(10.7760, 106.6810),
    LatLng(10.7770, 106.6820),
  ];

  test('driver active route is one blue navigation polyline', () {
    final polyline = DriverNavigationMap.activeRoutePolyline(route);

    expect(polyline.points, route);
    expect(polyline.color, AppColors.routeLine);
    expect(polyline.strokeWidth, 7);
  });

  testWidgets('driver map does not render customer traffic colors', (
    tester,
  ) async {
    final order = OrderModel.fromJson({
      'id': 'order-route-style',
      'customer_id': 'customer-1',
      'status': 'delivering',
      'pickup_address': 'Điểm lấy',
      'pickup_lat': 10.7750,
      'pickup_lng': 106.6800,
      'delivery_address': 'Điểm giao',
      'delivery_lat': 10.7770,
      'delivery_lng': 106.6820,
      'tracking_code': 'GH-ROUTE',
      'created_at': '2026-08-11T10:00:00Z',
      'updated_at': '2026-08-11T10:00:00Z',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 375,
          height: 700,
          child: DriverNavigationMap(
            mapController: MapController(),
            order: order,
            center: route.first,
            routePoints: route,
            driverPosition: route.first,
          ),
        ),
      ),
    );

    expect(find.byType(DeliveryTrafficRouteLayer), findsNothing);
  });
}
