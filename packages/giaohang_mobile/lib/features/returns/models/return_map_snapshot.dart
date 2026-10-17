import 'package:latlong2/latlong.dart';

import '../../../core/services/osrm_service.dart';

/// Trạng thái chỉ đọc cho bản đồ; màn hình đơn sở hữu chuyển động và nghiệp vụ.
class ReturnMapSnapshot {
  const ReturnMapSnapshot({
    this.position,
    this.route,
    this.step,
    this.maneuverDistance,
    this.distance,
    this.duration,
    this.loading = true,
    this.canStart = false,
    this.running = false,
    this.arrived = false,
    this.error,
  });

  final LatLng? position;
  final List<LatLng>? route;
  final OsrmNavigationStep? step;
  final double? maneuverDistance;
  final double? distance;
  final double? duration;
  final bool loading;
  final bool canStart;
  final bool running;
  final bool arrived;
  final String? error;
}
