import 'package:latlong2/latlong.dart';

import '../../../../../core/models/order_route_distance.dart';
import '../../../../../core/services/osrm_service.dart';

typedef DriverRouteQuoteKey = ({
  String orderId,
  String? driverId,
  DateTime? offerExpiresAt,
  double pickupLat,
  double pickupLng,
  double deliveryLat,
  double deliveryLng,
});

typedef _LegKey = ({
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
});

/// Ước tính hiển thị, độc lập với phí, matching, ETA và hạn giao của backend.
class DriverOrderRouteDistanceService {
  DriverOrderRouteDistanceService({OsrmService? osrm, DateTime Function()? now})
    : _osrm = osrm ?? OsrmService(),
      _now = now ?? DateTime.now;

  final OsrmService _osrm;
  final DateTime Function() _now;
  final _quotes = <DriverRouteQuoteKey, _RouteQuote>{};
  final _deliveryLegs = <_LegKey, Future<double?>>{};
  static const _cacheLimit = 64;
  static const _quoteLifetime = Duration(minutes: 2);

  Future<OrderRouteDistance> estimate({
    required DriverRouteQuoteKey key,
    LatLng? driverPosition,
    double? pickupRoadMeters,
  }) {
    final hasOrigin = _validPosition(driverPosition);
    final hasPickupQuote = OrderRouteDistance.isValidMeters(pickupRoadMeters);
    final previous = _quotes[key];
    if (previous != null &&
        _now().difference(previous.createdAt) < _quoteLifetime &&
        (previous.hasPickupOrigin || (!hasOrigin && !hasPickupQuote))) {
      return previous.result;
    }
    final result = _estimate(key, driverPosition, pickupRoadMeters);
    if (_quotes.length >= _cacheLimit) _quotes.remove(_quotes.keys.first);
    _quotes[key] = _RouteQuote(
      result: result,
      createdAt: _now(),
      hasPickupOrigin: hasOrigin || hasPickupQuote,
    );
    // Không giữ kết quả thiếu tuyến: lần mở lại/nhấn thử lại được phép lấy mới.
    result.then((distance) {
      if (distance.totalMeters == null && _quotes[key]?.result == result) {
        _quotes.remove(key);
      }
    });
    return result;
  }

  Future<OrderRouteDistance> _estimate(
    DriverRouteQuoteKey key,
    LatLng? driverPosition,
    double? pickupRoadMeters,
  ) async {
    if (!_validCoordinates(key.pickupLat, key.pickupLng) ||
        !_validCoordinates(key.deliveryLat, key.deliveryLng)) {
      return const OrderRouteDistance();
    }
    final pickup = LatLng(key.pickupLat, key.pickupLng);
    final delivery = LatLng(key.deliveryLat, key.deliveryLng);
    final distances = await Future.wait<double?>([
      OrderRouteDistance.isValidMeters(pickupRoadMeters)
          ? Future.value(pickupRoadMeters)
          : _routeMeters(driverPosition, pickup),
      _deliveryMeters(pickup, delivery),
    ]);
    return OrderRouteDistance(
      pickupMeters: distances[0],
      deliveryMeters: distances[1],
    );
  }

  Future<double?> _deliveryMeters(LatLng from, LatLng to) {
    final key = (
      fromLat: from.latitude,
      fromLng: from.longitude,
      toLat: to.latitude,
      toLng: to.longitude,
    );
    final previous = _deliveryLegs[key];
    if (previous != null) return previous;
    final result = _routeMeters(from, to);
    if (_deliveryLegs.length >= _cacheLimit) {
      _deliveryLegs.remove(_deliveryLegs.keys.first);
    }
    _deliveryLegs[key] = result;
    result.then((meters) {
      if (meters == null && _deliveryLegs[key] == result) {
        _deliveryLegs.remove(key);
      }
    });
    return result;
  }

  Future<double?> _routeMeters(LatLng? from, LatLng to) async {
    if (!_validPosition(from)) return null;
    if (from == to) return 0;
    try {
      final route = await _osrm
          .getRoute(
            startLat: from!.latitude,
            startLng: from.longitude,
            endLat: to.latitude,
            endLng: to.longitude,
          )
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      final meters = route?.distanceMeters;
      return OrderRouteDistance.isValidMeters(meters) ? meters : null;
    } catch (_) {
      return null;
    }
  }

  static bool _validPosition(LatLng? position) =>
      position != null &&
      _validCoordinates(position.latitude, position.longitude);

  static bool _validCoordinates(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      (lat != 0 || lng != 0);
}

class _RouteQuote {
  const _RouteQuote({
    required this.result,
    required this.createdAt,
    required this.hasPickupOrigin,
  });

  final Future<OrderRouteDistance> result;
  final DateTime createdAt;
  final bool hasPickupOrigin;
}
