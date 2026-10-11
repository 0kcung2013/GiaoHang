import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/models/order_model.dart';
import '../driver_home_strings.dart';
import '../providers/driver_order_route_distance_provider.dart';
import '../utils/driver_order_distance.dart';

/// Hiển thị cả hai chặng cùng nguồn khoảng cách theo tuyến đường.
class DriverOrderDistanceSummary extends ConsumerWidget {
  const DriverOrderDistanceSummary({
    super.key,
    required this.order,
    this.driverId,
    this.driverPosition,
  });

  final OrderModel order;
  final String? driverId;
  final LatLng? driverPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = driverOrderRouteRequest(
      order,
      driverId: driverId,
      driverPosition: driverPosition,
    );
    final state = ref.watch(driverOrderRouteDistanceProvider(request));
    final distance = state.valueOrNull;
    final status = state.isLoading
        ? DriverHomeStrings.routeDistanceLoading
        : distance?.totalMeters == null
        ? DriverHomeStrings.routeDistanceUnavailable
        : DriverHomeStrings.routeDistanceSource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              DriverHomeStrings.totalDistanceLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              distanceKilometersText(distance?.totalMeters),
              key: const ValueKey('driver-route-total-distance'),
              style: AppTextStyles.headingLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          status,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            _DistanceLeg(
              label: DriverHomeStrings.pickupDistanceLabel,
              meters: distance?.pickupMeters,
              icon: Icons.storefront_rounded,
              color: AppColors.markerPickup,
            ),
            _DistanceLeg(
              label: DriverHomeStrings.deliveryDistanceLabel,
              meters: distance?.deliveryMeters,
              icon: Icons.local_shipping_rounded,
              color: AppColors.markerDrop,
            ),
          ],
        ),
        if (!state.isLoading && distance?.totalMeters == null)
          TextButton.icon(
            onPressed: () =>
                ref.invalidate(driverOrderRouteDistanceProvider(request)),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(DriverHomeStrings.routeDistanceRetry),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: AppTextStyles.labelMedium,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
          ),
      ],
    );
  }
}

class _DistanceLeg extends StatelessWidget {
  const _DistanceLeg({
    required this.label,
    required this.meters,
    required this.icon,
    required this.color,
  });

  final String label;
  final double? meters;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: AppSpacing.xs),
      Flexible(
        child: Text(
          '$label: ${distanceKilometersText(meters)}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}
