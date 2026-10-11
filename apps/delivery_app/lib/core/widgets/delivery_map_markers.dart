import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../utils/delivery_traffic_route_analyzer.dart';
import 'delivery_traffic_map_layer.dart';

/// Marker thống nhất L / G / T cho map khách & tài xế.
class DeliveryMapMarkers {
  DeliveryMapMarkers._();

  static Marker speed(LatLng point, double kmh) => Marker(
    point: point,
    width: DriverSpeedLabel.width,
    height: DriverSpeedLabel.height,
    alignment: Alignment.center,
    rotate: true,
    child: Transform.translate(
      // Cùng neo GPS với xe, nhãn nằm bên phải và luôn đọc ngang khi xoay map.
      offset: const Offset(
        DriverVehicleMarker.size / 2 +
            AppSpacing.sm +
            DriverSpeedLabel.width / 2,
        0,
      ),
      child: DriverSpeedLabel(speedKmh: kmh),
    ),
  );

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

  static Marker driver(
    LatLng point, {
    bool highlight = true,
    double? bearingDegrees,
  }) => Marker(
    point: point,
    width: DriverVehicleMarker.size,
    height: DriverVehicleMarker.size,
    alignment: Alignment.center,
    child: _RotatedDriverMarker(
      isActive: highlight,
      bearingDegrees: bearingDegrees,
    ),
  );

  static Marker navigationDriver(
    LatLng point, {
    double? bearingDegrees,
  }) => Marker(
    point: point,
    width: DriverVehicleMarker.size,
    height: DriverVehicleMarker.size,
    alignment: Alignment.center,
    // The navigation camera already rotates the road toward the top of
    // the screen. Let this vehicle rotate with the map, so its heading
    // stays aligned with the forward route instead of being counter-rotated.
    rotate: false,
    child: _RotatedDriverMarker(isActive: true, bearingDegrees: bearingDegrees),
  );

  /// Chỉ lệch nhẹ khi **rất gần** (<12m) để không che chữ L/G.
  /// Không lệch mạnh — tránh cảm giác “sai vị trí”.
  static LatLng offsetIfNear(LatLng driver, LatLng other, {double minM = 12}) {
    final d = const Distance().as(LengthUnit.Meter, driver, other);
    if (d >= minM) return driver;
    return LatLng(driver.latitude + 0.00006, driver.longitude + 0.00005);
  }
}

class _RotatedDriverMarker extends StatelessWidget {
  const _RotatedDriverMarker({
    required this.isActive,
    required this.bearingDegrees,
  });

  final bool isActive;
  final double? bearingDegrees;

  @override
  Widget build(BuildContext context) {
    final bearing = bearingDegrees;
    final child = DriverVehicleMarker(isActive: isActive);
    if (bearing == null) return child;

    final angle = bearing * math.pi / 180;
    return Transform.rotate(angle: angle, child: child);
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

class DriverVehicleMarker extends StatelessWidget {
  const DriverVehicleMarker({required this.isActive, super.key});

  static const double size = 44;
  static const String assetPath = 'assets/images/delivery_scooter_marker.svg';

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Vị trí tài xế',
      child: Tooltip(
        message: 'Tài xế',
        child: RepaintBoundary(
          child: Opacity(
            opacity: isActive ? 1 : 0.58,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgCard,
                border: Border.all(color: AppColors.markerDriver, width: 2.5),
                boxShadow: AppShadow.card,
              ),
              child: SvgPicture.asset(
                assetPath,
                key: Key('driver-vehicle-marker'),
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DriverSpeedLabel extends StatelessWidget {
  const DriverSpeedLabel({required this.speedKmh, super.key});
  static const double width = 96;
  static const double height = 32;
  final double speedKmh;
  @override
  Widget build(BuildContext context) {
    final color = speedKmh <= 0
        ? AppColors.textSecondary
        : deliveryTrafficColor(
            DeliveryTrafficRouteAnalyzer.classifyMultiplier(50 / speedKmh),
          );
    return Semantics(
      label: 'Vận tốc ${speedKmh.round()} kilômét mỗi giờ',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.full,
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: AppShadow.subtle,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${speedKmh.round()} km/h',
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
