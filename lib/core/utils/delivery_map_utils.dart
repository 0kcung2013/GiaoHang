import 'package:latlong2/latlong.dart';

/// Tiện ích map giao hàng (chuẩn app giao hàng: Grab/ShopeeFood-like).
///
/// - Vạch xanh = **đường còn lại** (đã đi qua thì cắt, không vẽ full trip).
/// - Camera bám vị trí hiện tại + điểm đến tiếp theo.
class DeliveryMapUtils {
  DeliveryMapUtils._();

  static const Distance _distance = Distance();

  /// Điểm đích chặng hiện tại theo status đơn.
  static LatLng nextTarget({
    required String status,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) {
    if (status == 'delivering' || status == 'delivered') {
      return LatLng(deliveryLat, deliveryLng);
    }
    return LatLng(pickupLat, pickupLng);
  }

  /// Cắt polyline còn lại từ vị trí hiện tại → cuối tuyến.
  /// Bám **điểm trên route** (không kéo vạch lệch đường).
  static List<LatLng> remainingRoute({
    required List<LatLng> fullRoute,
    required LatLng current,
    double snapMaxMeters = 100,
  }) {
    if (fullRoute.length < 2) return fullRoute;

    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < fullRoute.length; i++) {
      final d = _distance.as(LengthUnit.Meter, current, fullRoute[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }

    // Xa route → current → đích (tránh vẽ sai cả tuyến)
    if (bestDist > snapMaxMeters * 5) {
      return [current, fullRoute.last];
    }

    // Còn lại: từ điểm snap trên polyline → cuối (không prepend current lệch)
    return fullRoute.sublist(bestIdx);
  }

  /// Snap marker TX lên polyline để không “lơ lửng” so với vạch xanh.
  static LatLng snapToRoute({
    required List<LatLng> fullRoute,
    required LatLng current,
    double maxSnapMeters = 120,
  }) {
    if (fullRoute.isEmpty) return current;
    var best = fullRoute.first;
    var bestDist = double.infinity;
    for (final p in fullRoute) {
      final d = _distance.as(LengthUnit.Meter, current, p);
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    if (bestDist <= maxSnapMeters) return best;
    return current;
  }

  /// Ước lượng mét còn lại trên polyline remaining.
  static double remainingMeters(List<LatLng> remaining) {
    if (remaining.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < remaining.length - 1; i++) {
      total += _distance.as(
        LengthUnit.Meter,
        remaining[i],
        remaining[i + 1],
      );
    }
    return total;
  }

  /// Điểm để fit camera: vị trí TX + đích chặng (+ optional điểm kia mờ).
  static List<LatLng> followFocusPoints({
    required LatLng? driver,
    required LatLng nextTarget,
    LatLng? secondaryAnchor,
    bool includeSecondary = false,
  }) {
    final pts = <LatLng>[];
    if (driver != null) pts.add(driver);
    pts.add(nextTarget);
    if (includeSecondary && secondaryAnchor != null) {
      pts.add(secondaryAnchor);
    }
    return pts;
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String formatDuration(double seconds) {
    if (seconds < 60) return '${seconds.round()} giây';
    final m = (seconds / 60).ceil();
    if (m < 60) return '$m phút';
    final h = m ~/ 60;
    final rm = m % 60;
    return rm == 0 ? '$h giờ' : '$h giờ $rm phút';
  }
}
