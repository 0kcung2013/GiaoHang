import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/services/osrm_service.dart';
import '../../../../../core/widgets/delivery_map_markers.dart';
import 'order_location_controls.dart';
import 'traffic_aware_order_route_layer.dart';

/// Bước 1/3: chọn điểm lấy, điểm giao và xem tuyến đường trên map toàn màn.
class OrderLocationStep extends StatefulWidget {
  const OrderLocationStep({
    super.key,
    required this.initialCenter,
    required this.pickup,
    required this.delivery,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.onPickPickup,
    required this.onPickDelivery,
    required this.onContinue,
    this.sampleRoutes,
  });

  final LatLng initialCenter;
  final LatLng? pickup;
  final LatLng? delivery;
  final String pickupAddress;
  final String deliveryAddress;
  final VoidCallback onPickPickup;
  final VoidCallback onPickDelivery;
  final VoidCallback onContinue;
  final Widget? sampleRoutes;

  @override
  State<OrderLocationStep> createState() => _OrderLocationStepState();
}

class _OrderLocationStepState extends State<OrderLocationStep> {
  final MapController _mapController = MapController();
  List<LatLng>? _route;
  OsrmRouteResult? _routeData;
  var _isLoadingRoute = false;
  var _requestId = 0;

  bool get _hasRoutePoints => widget.pickup != null && widget.delivery != null;

  @override
  void initState() {
    super.initState();
    _refreshRoute();
  }

  @override
  void didUpdateWidget(covariant OrderLocationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.delivery != widget.delivery) {
      _refreshRoute();
    }
  }

  Future<void> _refreshRoute() async {
    final requestId = ++_requestId;
    if (!_hasRoutePoints) {
      setState(() {
        _route = null;
        _routeData = null;
        _isLoadingRoute = false;
      });
      _focusPoints();
      return;
    }
    setState(() {
      _route = null;
      _routeData = null;
      _isLoadingRoute = true;
    });
    _focusPoints();
    final route = await OsrmService().getRouteWithWaypoints(
      waypoints: [widget.pickup!, widget.delivery!],
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _route = route?.points;
      _routeData = route;
      _isLoadingRoute = false;
    });
  }

  void _focusPoints() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = [
        if (widget.pickup != null) widget.pickup!,
        if (widget.delivery != null) widget.delivery!,
      ];
      try {
        if (points.length >= 2) {
          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.fromLTRB(40, 124, 40, 260),
              maxZoom: 16,
            ),
          );
        } else {
          _mapController.move(
            points.isEmpty ? widget.initialCenter : points.first,
            15,
          );
        }
      } catch (_) {
        // MapController có thể chưa attach ở frame đầu.
      }
    });
  }

  List<LatLng> get _visibleRoute =>
      _route ??
      [
        if (widget.pickup != null) widget.pickup!,
        if (widget.delivery != null) widget.delivery!,
      ];

  @override
  Widget build(BuildContext context) {
    final route = _visibleRoute;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.datn.giaohang',
              subdomains: const ['a', 'b', 'c'],
              maxNativeZoom: 19,
            ),
            if (route.length >= 2)
              TrafficAwareOrderRouteLayer(
                routePoints: route,
                quotedAt: DateTime.now(),
              ),
            MarkerLayer(
              markers: [
                if (widget.pickup != null)
                  DeliveryMapMarkers.pickup(widget.pickup!),
                if (widget.delivery != null)
                  DeliveryMapMarkers.dropoff(widget.delivery!),
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
              backgroundColor: AppColors.bgCard.withValues(alpha: 0.88),
            ),
          ],
        ),
        const _MapTopShade(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: _LocationStepHeader(
              onClose: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.lg,
          top: MediaQuery.paddingOf(context).top + 76,
          child: _MapActionButton(onTap: _focusPoints),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: OrderLocationControlSheet(
              pickupAddress: widget.pickupAddress,
              deliveryAddress: widget.deliveryAddress,
              pickupSelected: widget.pickup != null,
              deliverySelected: widget.delivery != null,
              route: _routeData,
              isLoadingRoute: _isLoadingRoute,
              onPickPickup: widget.onPickPickup,
              onPickDelivery: widget.onPickDelivery,
              onContinue: _hasRoutePoints ? widget.onContinue : null,
              sampleRoutes: widget.sampleRoutes,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapTopShade extends StatelessWidget {
  const _MapTopShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationStepHeader extends StatelessWidget {
  const _LocationStepHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: AppColors.bgCard,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onClose,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.96),
              borderRadius: AppRadius.full,
              boxShadow: AppShadow.subtle,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.route_rounded,
                  size: 19,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Chọn vị trí',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '1 / 3',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      shape: const CircleBorder(),
      elevation: 2,
      child: Tooltip(
        message: 'Căn giữa tuyến đường',
        child: InkWell(
          onTap: onTap,
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
    );
  }
}

// TODO(refactor): Remove after the next clean-up pass; controls live in
// order_location_controls.dart.
// ignore: unused_element
class _LocationControlSheet extends StatelessWidget {
  const _LocationControlSheet({
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.pickupSelected,
    required this.deliverySelected,
    required this.route,
    required this.isLoadingRoute,
    required this.onPickPickup,
    required this.onPickDelivery,
    required this.onContinue,
  });

  final String pickupAddress;
  final String deliveryAddress;
  final bool pickupSelected;
  final bool deliverySelected;
  final OsrmRouteResult? route;
  final bool isLoadingRoute;
  final VoidCallback onPickPickup;
  final VoidCallback onPickDelivery;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final hasRoadRoute = route != null;
    final routeText = isLoadingRoute
        ? 'Đang tìm đường'
        : hasRoadRoute
        ? '${(route!.distanceMeters / 1000).toStringAsFixed(1)} km · ${route!.durationMinutes.ceil()} phút'
        : pickupSelected && deliverySelected
        ? 'Đường kết nối hai điểm'
        : 'Chọn điểm lấy và điểm giao';
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl2,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.elevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocationStopRow(
            marker: 'L',
            color: AppColors.markerPickup,
            label: 'Điểm lấy hàng',
            value: pickupAddress,
            selected: pickupSelected,
            onTap: onPickPickup,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LocationStopRow(
            marker: 'G',
            color: AppColors.markerDrop,
            label: 'Điểm giao hàng',
            value: deliveryAddress,
            selected: deliverySelected,
            onTap: onPickDelivery,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                isLoadingRoute ? Icons.more_horiz_rounded : Icons.route_rounded,
                size: 18,
                color: AppColors.routeLine,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  routeText,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: Material(
              color: onContinue == null ? AppColors.border : AppColors.accent,
              borderRadius: AppRadius.full,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onContinue,
                borderRadius: AppRadius.full,
                child: Center(
                  child: Text(
                    'Xem giá giao hàng',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: onContinue == null
                          ? AppColors.textMuted
                          : AppColors.textOnAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationStopRow extends StatelessWidget {
  const _LocationStopRow({
    required this.marker,
    required this.color,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String marker;
  final Color color;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, ${selected ? 'đã chọn' : 'chưa chọn'}',
      child: Material(
        color: selected ? color.withValues(alpha: 0.06) : AppColors.bgLight,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    marker,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textOnAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected ? value : 'Chạm để chọn trên bản đồ',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
