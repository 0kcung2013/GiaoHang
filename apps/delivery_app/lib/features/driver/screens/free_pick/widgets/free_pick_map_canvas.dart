import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/services/free_pick_service.dart';

class FreePickMapCanvas extends StatelessWidget {
  const FreePickMapCanvas({
    super.key,
    this.mapController,
    required this.driverPosition,
    required this.orders,
    required this.selectedOrderId,
    required this.onMapSettled,
    required this.onOrderSelected,
    required this.onLocate,
    this.showBaseMap = true,
  });

  static const serviceRadiusMeters = 3000.0;
  static const fallbackCenter = LatLng(10.7769, 106.7009);

  final MapController? mapController;
  final LatLng? driverPosition;
  final List<OrderModel> orders;
  final String? selectedOrderId;
  final ValueChanged<FreePickViewport> onMapSettled;
  final ValueChanged<OrderModel> onOrderSelected;
  final VoidCallback onLocate;
  final bool showBaseMap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: driverPosition ?? fallbackCenter,
            initialZoom: 13,
            minZoom: 8,
            maxZoom: 19,
            onMapReady: () => _emitViewport(mapController),
            onMapEvent: (event) {
              if (event is MapEventMoveEnd ||
                  event is MapEventFlingAnimationEnd ||
                  event is MapEventDoubleTapZoomEnd) {
                _emitBounds(event.camera.visibleBounds);
              }
            },
          ),
          children: [
            if (showBaseMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.datn.giaohang',
                maxNativeZoom: 19,
              ),
            if (driverPosition != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: driverPosition!,
                    radius: serviceRadiusMeters,
                    useRadiusInMeter: true,
                    color: AppColors.info.withValues(alpha: 0.16),
                    borderColor: AppColors.info.withValues(alpha: 0.92),
                    borderStrokeWidth: 2.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (driverPosition != null) _driverMarker(driverPosition!),
                ...orders.map(_orderMarker),
              ],
            ),
            if (showBaseMap)
              SimpleAttributionWidget(
                source: Text(
                  'OpenStreetMap contributors',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
                backgroundColor: AppColors.bgCard.withValues(alpha: 0.86),
              ),
          ],
        ),
        Positioned(
          right: AppSpacing.md,
          top: AppSpacing.xl5 + AppSpacing.sm,
          child: Tooltip(
            message: 'Về vị trí hiện tại',
            child: Semantics(
              button: true,
              label: 'Về vị trí hiện tại và xem bán kính 3 km',
              child: Material(
                color: AppColors.info,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  onTap: onLocate,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppColors.textOnAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (driverPosition != null)
          Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.xl2 + 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.94),
                borderRadius: AppRadius.full,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.34),
                ),
                boxShadow: AppShadow.card,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.info,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Bán kính tự động 3 km',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Marker _driverMarker(LatLng position) {
    return Marker(
      point: position,
      width: 46,
      height: 46,
      child: const _MapPin(
        icon: Icons.navigation_rounded,
        color: AppColors.success,
        semanticLabel: 'Vị trí tài xế',
      ),
    );
  }

  Marker _orderMarker(OrderModel order) {
    final selected = order.id == selectedOrderId;
    return Marker(
      point: LatLng(order.pickupLat, order.pickupLng),
      width: selected ? 54 : 46,
      height: selected ? 54 : 46,
      child: GestureDetector(
        onTap: () => onOrderSelected(order),
        child: _MapPin(
          icon: Icons.inventory_2_rounded,
          color: selected ? AppColors.accent : AppColors.markerPickup,
          semanticLabel: 'Chọn đơn ${order.trackingCode}',
        ),
      ),
    );
  }

  void _emitViewport(MapController? controller) {
    if (controller == null) return;
    _emitBounds(controller.camera.visibleBounds);
  }

  void _emitBounds(LatLngBounds bounds) {
    onMapSettled(
      FreePickViewport(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.icon,
    required this.color,
    required this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bgCard, width: 3),
          boxShadow: AppShadow.card,
        ),
        child: Icon(icon, size: 20, color: AppColors.textOnAccent),
      ),
    );
  }
}
