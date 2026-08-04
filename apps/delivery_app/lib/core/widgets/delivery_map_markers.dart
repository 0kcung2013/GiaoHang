import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';

/// Marker thống nhất L / G / T cho map khách & tài xế.
class DeliveryMapMarkers {
  DeliveryMapMarkers._();

  static const driverAssetPath = 'assets/images/driver_map_marker.png';

  static Marker pickup(LatLng point) => Marker(
    point: point,
    width: 40,
    height: 40,
    alignment: Alignment.center,
    child: const _BubbleMarker(
      color: AppColors.markerPickup,
      label: 'L',
      tooltip: 'Lấy hàng',
    ),
  );

  static Marker dropoff(LatLng point) => Marker(
    point: point,
    width: 40,
    height: 40,
    alignment: Alignment.center,
    child: const _BubbleMarker(
      color: AppColors.markerDrop,
      label: 'G',
      tooltip: 'Giao hàng',
    ),
  );

  static Marker driver(LatLng point, {bool highlight = true}) => Marker(
    point: point,
    width: 68,
    height: 68,
    alignment: Alignment.center,
    child: _DriverMarker(isActive: highlight),
  );

  static Marker navigationDriver(LatLng point) => Marker(
    point: point,
    width: 76,
    height: 76,
    alignment: Alignment.center,
    rotate: true,
    child: const _DriverMarker(isActive: true),
  );

  /// Chỉ lệch nhẹ khi **rất gần** (<12m) để không che chữ L/G.
  /// Không lệch mạnh — tránh cảm giác “sai vị trí”.
  static LatLng offsetIfNear(LatLng driver, LatLng other, {double minM = 12}) {
    final d = const Distance().as(LengthUnit.Meter, driver, other);
    if (d >= minM) return driver;
    return LatLng(driver.latitude + 0.00006, driver.longitude + 0.00005);
  }
}

class _BubbleMarker extends StatelessWidget {
  const _BubbleMarker({
    required this.color,
    required this.label,
    required this.tooltip,
  });

  final Color color;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: AppShadow.card,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Vị trí tài xế',
      child: Tooltip(
        message: 'Tài xế',
        child: Stack(
          key: const Key('driver-map-marker-stack'),
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              DeliveryMapMarkers.driverAssetPath,
              key: const Key('driver-map-marker-icon'),
              fit: BoxFit.contain,
              cacheWidth: 192,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Tài xế giao hàng',
            ),
            if (isActive)
              Positioned(
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Container(
                  key: const Key('driver-map-marker-active-dot'),
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.markerDriver,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
