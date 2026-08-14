part of '../tracking_screen.dart';

void _openTrackingFullscreen(BuildContext context, OrderModel order) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => _TrackingFullscreenMap(order: order),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 250),
    ),
  );
}

class _TrackingFullscreenMap extends StatelessWidget {
  const _TrackingFullscreenMap({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _TrackingMap(order: order, isFullscreen: true);
  }
}

class TrackingMapCanvas extends StatelessWidget {
  const TrackingMapCanvas({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.fullRoute,
    required this.trafficSegments,
    required this.pickupPoint,
    required this.deliveryPoint,
    required this.driverPosition,
    required this.completed,
    required this.isFullscreen,
    required this.phaseLegend,
    required this.onOpenFullscreen,
    required this.onCloseFullscreen,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final List<LatLng>? fullRoute;
  final List<DeliveryTrafficSegment> trafficSegments;
  final LatLng pickupPoint;
  final LatLng deliveryPoint;
  final LatLng? driverPosition;
  final bool completed;
  final bool isFullscreen;
  final String phaseLegend;
  final VoidCallback onOpenFullscreen;
  final VoidCallback onCloseFullscreen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: initialCenter, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.datn.giaohang',
              subdomains: const ['a', 'b', 'c'],
              maxNativeZoom: 19,
            ),
            if (fullRoute != null && fullRoute!.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: fullRoute!,
                    color: AppColors.routeLine.withValues(alpha: 0.2),
                    strokeWidth: 4,
                  ),
                ],
              ),
            if (trafficSegments.isNotEmpty)
              DeliveryTrafficRouteLayer(
                segments: trafficSegments,
                strokeWidth: 5,
              ),
            MarkerLayer(
              markers: [
                DeliveryMapMarkers.pickup(pickupPoint),
                DeliveryMapMarkers.dropoff(deliveryPoint),
                if (driverPosition != null)
                  DeliveryMapMarkers.driver(
                    completed
                        ? driverPosition!
                        : DeliveryMapMarkers.offsetIfNear(
                            DeliveryMapMarkers.offsetIfNear(
                              driverPosition!,
                              pickupPoint,
                            ),
                            deliveryPoint,
                          ),
                  ),
              ],
            ),
          ],
        ),
        if (trafficSegments.isNotEmpty)
          Positioned(
            left: AppSpacing.sm,
            top: isFullscreen ? 72 : AppSpacing.sm,
            right: AppSpacing.sm,
            child: DeliveryTrafficMapLegend(segments: trafficSegments),
          ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: AppRadius.md,
              boxShadow: AppShadow.subtle,
            ),
            child: Text(
              phaseLegend,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (!isFullscreen)
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _TrackingMapActionButton(
              icon: Icons.fullscreen_rounded,
              label: 'Xem bản đồ',
              onTap: onOpenFullscreen,
            ),
          ),
        if (isFullscreen)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: _TrackingMapActionButton(
              icon: Icons.arrow_back_rounded,
              label: 'Theo dõi đơn',
              onTap: onCloseFullscreen,
            ),
          ),
      ],
    );
  }
}

extension on _TrackingMapState {
  void _fitCamera(LatLng? driver) {
    if (_hasInitialCameraFit) return;
    final points = _phase.cameraPoints(
      driver: driver,
      pickup: LatLng(widget.order.pickupLat, widget.order.pickupLng),
      delivery: LatLng(widget.order.deliveryLat, widget.order.deliveryLng),
    );
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: widget.isFullscreen
              ? const EdgeInsets.fromLTRB(40, 112, 40, 96)
              : const EdgeInsets.fromLTRB(40, 48, 40, 48),
          maxZoom: 16,
        ),
      );
      _hasInitialCameraFit = true;
    } catch (_) {
      try {
        _mapController.move(points.first, 15);
        _hasInitialCameraFit = true;
      } catch (_) {}
    }
  }
}

class _TrackingMapActionButton extends StatelessWidget {
  const _TrackingMapActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.bgCard.withValues(alpha: 0.96),
        borderRadius: AppRadius.full,
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.primary, size: 22),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
