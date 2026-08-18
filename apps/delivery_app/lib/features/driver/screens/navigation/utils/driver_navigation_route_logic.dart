import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/services/osrm_service.dart';
import '../../../../../core/utils/delivery_map_utils.dart';

class DriverNavigationRouteLogic {
  const DriverNavigationRouteLogic._();

  static const double maneuverAdvanceRadiusMeters = 35;
  static const double navigationZoom = 17.8;
  static const double navigationLookAheadMeters = 70;
  static const Offset navigationDriverOffset = Offset(0, 104);

  static List<LatLng> buildWaypoints({
    required OrderModel order,
    required LatLng driverPosition,
  }) {
    final pickup = LatLng(order.pickupLat, order.pickupLng);
    final delivery = LatLng(order.deliveryLat, order.deliveryLng);
    final distanceToPickup = const Distance().as(
      LengthUnit.Meter,
      driverPosition,
      pickup,
    );

    if (distanceToPickup > 150000) {
      debugPrint(
        '[OSRM_DEBUG_DRIVER] Driver too far '
        '(${distanceToPickup.toStringAsFixed(0)}m). '
        'Routing [pickup→delivery].',
      );
      return [pickup, delivery];
    }

    if (order.status == 'delivering') {
      return [driverPosition, delivery];
    }
    return [driverPosition, pickup];
  }

  static int nearestRouteIndex(List<LatLng> points, LatLng position) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    const distance = Distance();
    for (var index = 0; index < points.length; index++) {
      final meters = distance.as(LengthUnit.Meter, position, points[index]);
      if (meters < bestDistance) {
        bestDistance = meters;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  static void followDriverCamera({
    required MapController controller,
    required OrderModel order,
    required LatLng driverPosition,
    required List<LatLng>? routePoints,
  }) {
    final target = DeliveryMapUtils.nextTarget(
      status: order.status,
      pickupLat: order.pickupLat,
      pickupLng: order.pickupLng,
      deliveryLat: order.deliveryLat,
      deliveryLng: order.deliveryLng,
    );
    followRouteCamera(
      controller: controller,
      driverPosition: driverPosition,
      routePoints: routePoints,
      fallbackTarget: target,
    );
  }

  static void followRouteCamera({
    required MapController controller,
    required LatLng driverPosition,
    required List<LatLng>? routePoints,
    required LatLng fallbackTarget,
  }) {
    final cameraRoute = routePoints != null && routePoints.length >= 2
        ? routePoints
        : [driverPosition, fallbackTarget];
    final plan = navigationCameraPlan(
      driverPosition: driverPosition,
      routePoints: cameraRoute,
    );

    try {
      controller.rotate(plan.rotation);
      controller.move(driverPosition, plan.zoom, offset: plan.driverOffset);
    } catch (_) {
      try {
        controller.move(driverPosition, plan.zoom);
      } catch (_) {}
    }
  }

  static void fitMapBounds({
    required MapController controller,
    required OrderModel order,
    required LatLng? driverPosition,
    required List<LatLng>? routePoints,
  }) {
    if (driverPosition != null) {
      followDriverCamera(
        controller: controller,
        order: order,
        driverPosition: driverPosition,
        routePoints: routePoints,
      );
      return;
    }
    final target = DeliveryMapUtils.nextTarget(
      status: order.status,
      pickupLat: order.pickupLat,
      pickupLng: order.pickupLng,
      deliveryLat: order.deliveryLat,
      deliveryLng: order.deliveryLng,
    );
    try {
      controller.move(target, 15);
    } catch (_) {}
  }

  static int advanceNavigationStepIndex({
    required List<OsrmNavigationStep> steps,
    required int currentIndex,
    required LatLng driverPosition,
  }) {
    if (steps.length < 2) return currentIndex;

    var activeIndex = currentIndex;
    var nextIndex = activeIndex + 1;
    while (nextIndex < steps.length) {
      final meters = const Distance().as(
        LengthUnit.Meter,
        driverPosition,
        steps[nextIndex].location,
      );
      if (meters > maneuverAdvanceRadiusMeters) break;
      activeIndex = nextIndex;
      nextIndex++;
    }
    return activeIndex;
  }

  static OsrmNavigationStep? nextNavigationStep({
    required List<OsrmNavigationStep> steps,
    required int activeIndex,
  }) {
    if (steps.isEmpty) return null;
    final nextIndex = activeIndex + 1;
    return steps[nextIndex < steps.length ? nextIndex : steps.length - 1];
  }

  static double navigationRotationDegrees({
    required LatLng driverPosition,
    required List<LatLng> routePoints,
  }) {
    final lookAhead = _lookAheadPoint(
      driverPosition: driverPosition,
      routePoints: routePoints,
    );
    if (lookAhead == null) return 0;
    final bearing = const Distance().bearing(driverPosition, lookAhead);
    return normalizeBearing(-bearing);
  }

  static ({double rotation, double zoom, Offset driverOffset})
  navigationCameraPlan({
    required LatLng driverPosition,
    required List<LatLng> routePoints,
  }) {
    return (
      rotation: navigationRotationDegrees(
        driverPosition: driverPosition,
        routePoints: routePoints,
      ),
      zoom: navigationZoom,
      driverOffset: navigationDriverOffset,
    );
  }

  static LatLng? _lookAheadPoint({
    required LatLng driverPosition,
    required List<LatLng> routePoints,
  }) {
    if (routePoints.length < 2) return null;
    final remaining = DeliveryMapUtils.remainingRoute(
      fullRoute: routePoints,
      current: driverPosition,
    );
    if (remaining.length < 2) return null;

    const distance = Distance();
    var travelled = 0.0;
    var previous = remaining.first;
    for (final point in remaining.skip(1)) {
      final segmentMeters = distance.as(LengthUnit.Meter, previous, point);
      if (travelled + segmentMeters >= navigationLookAheadMeters) {
        final offsetMeters = navigationLookAheadMeters - travelled;
        final bearing = distance.bearing(previous, point);
        return distance.offset(previous, offsetMeters, bearing);
      }
      travelled += segmentMeters;
      previous = point;
    }
    return remaining.last;
  }
}
