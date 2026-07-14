import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/location_providers.dart';

class DriverHomeMap extends ConsumerStatefulWidget {
  final List<OrderModel> availableOrders;
  final List<OrderModel> activeOrders;

  const DriverHomeMap({
    super.key,
    required this.availableOrders,
    required this.activeOrders,
  });

  @override
  ConsumerState<DriverHomeMap> createState() => _DriverHomeMapState();
}

class _DriverHomeMapState extends ConsumerState<DriverHomeMap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(currentPositionProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(currentPositionProvider);
    final driverPos = positionAsync.valueOrNull;
    final center = (driverPos != null)
        ? LatLng(driverPos.latitude, driverPos.longitude)
        : const LatLng(10.762622, 106.660172);

    final markers = <Marker>[];

    if (driverPos != null) {
      markers.add(
        Marker(
          point: LatLng(driverPos.latitude, driverPos.longitude),
          child: const _DriverMarker(),
        ),
      );
    }

    for (final order in widget.availableOrders) {
      if (order.pickupLat == 0 && order.pickupLng == 0) continue;
      markers.add(
        Marker(
          point: LatLng(order.pickupLat, order.pickupLng),
          child: const _OrderMarker(),
        ),
      );
    }

    for (final order in widget.activeOrders) {
      if (order.pickupLat != 0 && order.pickupLng != 0) {
        markers.add(
          Marker(
            point: LatLng(order.pickupLat, order.pickupLng),
            child: const _PickupMarker(),
          ),
        );
      }
      if (order.deliveryLat != 0 && order.deliveryLng != 0) {
        markers.add(
          Marker(
            point: LatLng(order.deliveryLat, order.deliveryLng),
            child: const _DeliveryMarker(),
          ),
        );
      }
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.datn.giaohang',
            subdomains: const ['a', 'b', 'c'],
            maxNativeZoom: 19,
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.markerDriver,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: AppShadow.subtle,
      ),
      child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 16),
    );
  }
}

class _OrderMarker extends StatelessWidget {
  const _OrderMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.markerDrop,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppShadow.subtle,
      ),
      child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 12),
    );
  }
}

class _PickupMarker extends StatelessWidget {
  const _PickupMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.markerPickup,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppShadow.subtle,
      ),
      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 14),
    );
  }
}

class _DeliveryMarker extends StatelessWidget {
  const _DeliveryMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.markerDrop,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppShadow.subtle,
      ),
      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
    );
  }
}
