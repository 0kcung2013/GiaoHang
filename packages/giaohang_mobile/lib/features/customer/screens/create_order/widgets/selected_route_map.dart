import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/services/osrm_service.dart';
import '../../../../../core/widgets/delivery_map_markers.dart';

/// Bản xem trước tuyến đường sau khi khách đã chọn đủ hai điểm.
///
/// Vẽ đường thẳng ngay để phản hồi tức thì, sau đó thay bằng tuyến đường bộ
/// từ OSRM khi yêu cầu hoàn tất.
class SelectedRouteMap extends StatefulWidget {
  const SelectedRouteMap({
    super.key,
    required this.pickup,
    required this.delivery,
  });

  final LatLng pickup;
  final LatLng delivery;

  @override
  State<SelectedRouteMap> createState() => _SelectedRouteMapState();
}

class _SelectedRouteMapState extends State<SelectedRouteMap> {
  final MapController _mapController = MapController();
  List<LatLng>? _route;
  OsrmRouteResult? _routeData;
  var _isLoading = true;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    _refreshRoute();
  }

  @override
  void didUpdateWidget(covariant SelectedRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.delivery != widget.delivery) {
      _refreshRoute();
    }
  }

  Future<void> _refreshRoute() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _route = null;
      _routeData = null;
    });
    _fitCamera();

    final result = await OsrmService().getRouteWithWaypoints(
      waypoints: [widget.pickup, widget.delivery],
    );
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _isLoading = false;
      _routeData = result;
      _route = result?.points;
    });
  }

  void _fitCamera() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: [widget.pickup, widget.delivery],
            padding: const EdgeInsets.fromLTRB(36, 48, 36, 72),
            maxZoom: 16,
          ),
        );
      } catch (_) {
        // MapController chưa sẵn sàng ở frame đầu; initialCenter vẫn hợp lệ.
      }
    });
  }

  List<LatLng> get _visibleRoute => _route ?? [widget.pickup, widget.delivery];

  @override
  Widget build(BuildContext context) {
    final route = _visibleRoute;
    final midPoint = LatLng(
      (widget.pickup.latitude + widget.delivery.latitude) / 2,
      (widget.pickup.longitude + widget.delivery.longitude) / 2,
    );

    return Semantics(
      container: true,
      label: 'Bản đồ tuyến đường dự kiến từ điểm lấy đến điểm giao',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 236,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: midPoint,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.datn.giaohang',
                        subdomains: const ['a', 'b', 'c'],
                        maxNativeZoom: 19,
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route,
                            color: AppColors.bgCard.withValues(alpha: 0.92),
                            strokeWidth: 8,
                          ),
                          Polyline(
                            points: route,
                            color: AppColors.routeLine,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          DeliveryMapMarkers.pickup(widget.pickup),
                          DeliveryMapMarkers.dropoff(widget.delivery),
                        ],
                      ),
                      SimpleAttributionWidget(
                        source: Text(
                          'OpenStreetMap',
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        backgroundColor: AppColors.bgCard.withValues(
                          alpha: 0.88,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: _RouteMapLabel(
                      isLoading: _isLoading,
                      hasRoute: _routeData != null,
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: Material(
                      color: AppColors.bgCard,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _fitCamera,
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.center_focus_strong_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _RouteSummary(route: _routeData, isLoading: _isLoading),
          ],
        ),
      ),
    );
  }
}

class _RouteMapLabel extends StatelessWidget {
  const _RouteMapLabel({required this.isLoading, required this.hasRoute});

  final bool isLoading;
  final bool hasRoute;

  @override
  Widget build(BuildContext context) {
    final label = isLoading
        ? 'Đang tìm đường'
        : hasRoute
        ? 'Tuyến đường dự kiến'
        : 'Đường kết nối hai điểm';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.95),
        borderRadius: AppRadius.full,
        boxShadow: AppShadow.subtle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: AppColors.routeLine,
            )
          else
            const Icon(
              Icons.route_rounded,
              size: 17,
              color: AppColors.routeLine,
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.route, required this.isLoading});

  final OsrmRouteResult? route;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final hasRoute = route != null;
    final detail = isLoading
        ? 'Đang cập nhật lộ trình thực tế...'
        : hasRoute
        ? '${(route!.distanceMeters / 1000).toStringAsFixed(1)} km · ${route!.durationMinutes.ceil()} phút'
        : 'Không thể tải đường bộ. Bạn vẫn có thể xem giá.';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _StopBadge(
            label: 'L',
            color: AppColors.markerPickup,
            tooltip: 'Điểm lấy hàng',
          ),
          Container(
            width: 18,
            height: 2,
            color: AppColors.routeLine.withValues(alpha: 0.45),
          ),
          _StopBadge(
            label: 'G',
            color: AppColors.markerDrop,
            tooltip: 'Điểm giao hàng',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: hasRoute
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopBadge extends StatelessWidget {
  const _StopBadge({
    required this.label,
    required this.color,
    required this.tooltip,
  });

  final String label;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textOnAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
