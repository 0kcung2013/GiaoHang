import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/delivery_map_markers.dart';

class ReturnNavigationMap extends StatelessWidget {
  const ReturnNavigationMap({
    required this.controller,
    required this.destination,
    required this.position,
    required this.route,
    super.key,
  });

  final MapController controller;
  final LatLng destination;
  final LatLng? position;
  final List<LatLng>? route;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: position ?? destination,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.datn.giaohang',
          maxNativeZoom: 19,
        ),
        if (route != null && route!.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route!,
                color: AppColors.bgCard.withValues(alpha: 0.92),
                strokeWidth: 11,
              ),
              Polyline(
                points: route!,
                color: AppColors.routeLine,
                strokeWidth: 7,
              ),
            ],
          ),
        MarkerLayer(
          rotate: true,
          markers: [
            DeliveryMapMarkers.pickup(destination),
            if (position != null)
              DeliveryMapMarkers.navigationDriver(
                DeliveryMapMarkers.offsetIfNear(position!, destination),
              ),
          ],
        ),
      ],
    );
  }
}
