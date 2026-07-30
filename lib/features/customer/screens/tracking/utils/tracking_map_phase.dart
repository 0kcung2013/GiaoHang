import 'package:latlong2/latlong.dart';

enum TrackingMapPhase {
  toPickup,
  toDelivery,
  completed;

  factory TrackingMapPhase.fromStatus(String status) {
    return switch (status) {
      'delivering' => TrackingMapPhase.toDelivery,
      'delivered' => TrackingMapPhase.completed,
      _ => TrackingMapPhase.toPickup,
    };
  }

  bool get tracksLiveDriver => this != TrackingMapPhase.completed;

  String get legend => switch (this) {
    TrackingMapPhase.toPickup => 'T → L · đang lấy hàng',
    TrackingMapPhase.toDelivery => 'T → G · đang giao',
    TrackingMapPhase.completed => 'L → G · đã giao hàng',
  };

  LatLng? visibleDriverPosition({
    required LatLng? latestDriverPosition,
    required LatLng delivery,
  }) {
    if (this == TrackingMapPhase.completed) {
      return delivery;
    }
    return latestDriverPosition;
  }

  List<LatLng> routeWaypoints({
    required LatLng? driver,
    required LatLng pickup,
    required LatLng delivery,
  }) {
    if (this == TrackingMapPhase.completed || driver == null) {
      return [pickup, delivery];
    }

    return [driver, this == TrackingMapPhase.toDelivery ? delivery : pickup];
  }

  List<LatLng> cameraPoints({
    required LatLng? driver,
    required LatLng pickup,
    required LatLng delivery,
  }) {
    return routeWaypoints(driver: driver, pickup: pickup, delivery: delivery);
  }
}
