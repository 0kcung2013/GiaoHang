import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/services/osrm_service.dart';

class OrderLocationControlSheet extends StatelessWidget {
  const OrderLocationControlSheet({
    super.key,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.pickupSelected,
    required this.deliverySelected,
    required this.route,
    required this.isLoadingRoute,
    required this.onPickPickup,
    required this.onPickDelivery,
    required this.onContinue,
    this.sampleRoutes,
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
  final Widget? sampleRoutes;

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
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.xs),
          _LocationStopRow(
            marker: 'G',
            color: AppColors.markerDrop,
            label: 'Điểm giao hàng',
            value: deliveryAddress,
            selected: deliverySelected,
            onTap: onPickDelivery,
          ),
          if (sampleRoutes != null) ...[
            const SizedBox(height: AppSpacing.xs),
            sampleRoutes!,
          ],
          if (isLoadingRoute || hasRoadRoute) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  isLoadingRoute
                      ? Icons.more_horiz_rounded
                      : Icons.route_rounded,
                  size: 17,
                  color: AppColors.routeLine,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    routeText,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Material(
              color: onContinue == null ? AppColors.border : AppColors.accent,
              borderRadius: AppRadius.full,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onContinue,
                borderRadius: AppRadius.full,
                child: Center(
                  child: Text(
                    'Tiếp tục',
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          color: selected ? color.withValues(alpha: 0.06) : AppColors.bgLight,
          borderRadius: AppRadius.md,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.md,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected ? value : 'Chạm để chọn trên bản đồ',
                          maxLines: 1,
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
                    size: 20,
                    color: AppColors.textMuted,
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
