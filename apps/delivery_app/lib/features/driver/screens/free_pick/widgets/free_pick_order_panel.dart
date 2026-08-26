import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../../home/utils/driver_home_formatters.dart';
import '../../home/utils/driver_order_distance.dart';

class FreePickOrderPanel extends StatelessWidget {
  const FreePickOrderPanel({
    super.key,
    required this.order,
    required this.isClaiming,
    required this.onClaim,
    this.driverLat,
    this.driverLng,
    this.position = 1,
    this.totalCount = 1,
  });

  final OrderModel order;
  final bool isClaiming;
  final VoidCallback? onClaim;
  final double? driverLat;
  final double? driverLng;
  final int position;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final distance = totalOrderDistanceMeters(
      order: order,
      driverLat: driverLat,
      driverLng: driverLng,
    );
    final isDemo = order.trackingCode.toUpperCase().contains('DEMO');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadow.elevated,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.markerPickup.withValues(alpha: 0.12),
                    borderRadius: AppRadius.md,
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.markerPickup,
                    size: 21,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayOrderCode(order),
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          'FreePick $position/$totalCount',
                          if (distance != null)
                            totalOrderDistanceText(distance),
                        ].join(' • '),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatVnd(order.driverNetEarning),
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _MetricChip(
                  icon: Icons.payments_rounded,
                  label: 'COD ${formatVnd(order.codCollectionAmount)}',
                  color: AppColors.accent,
                ),
                if (isDemo)
                  const _MetricChip(
                    icon: Icons.all_inclusive_rounded,
                    label: 'Demo không hết hạn',
                    color: AppColors.info,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _RouteLine(
              icon: Icons.radio_button_checked_rounded,
              color: AppColors.markerPickup,
              text: order.pickupAddress,
            ),
            const SizedBox(height: AppSpacing.sm),
            _RouteLine(
              icon: Icons.location_on_rounded,
              color: AppColors.markerDrop,
              text: order.deliveryAddress,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: isClaiming ? null : onClaim,
                icon: Icon(
                  isClaiming
                      ? Icons.more_horiz_rounded
                      : Icons.check_circle_rounded,
                ),
                label: Text(isClaiming ? 'Đang nhận đơn' : 'Nhận đơn FreePick'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  disabledBackgroundColor: AppColors.accent.withValues(
                    alpha: 0.55,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                  textStyle: AppTextStyles.labelLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
