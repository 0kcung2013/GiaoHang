import 'package:delivery_app/features/customer/screens/create_order/widgets/traffic_aware_order_route_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'order route uses historical traffic colors instead of the blue OSRM line',
    () {
      final polylines = TrafficAwareOrderRouteLayer.polylinesFor(
        routePoints: const [
          LatLng(10.775, 106.680),
          LatLng(10.780, 106.685),
          LatLng(10.785, 106.690),
        ],
        quotedAt: DateTime(2026, 8, 7, 17, 30),
      );

      expect(polylines, hasLength(greaterThan(1)));
      expect(polylines.first.color, Colors.white.withValues(alpha: 0.92));
      expect(
        polylines
            .skip(1)
            .every((polyline) => polyline.color != AppColors.routeLine),
        isTrue,
      );
    },
  );
}
