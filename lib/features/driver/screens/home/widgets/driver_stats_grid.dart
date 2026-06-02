import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/driver_model.dart';
import '../../../../../core/models/order_model.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_home_layout.dart';

/// Data class computed from live order lists and driver profile.
class DriverStats {
  final int availableOrders;
  final int assignedOrders;
  final int activeDeliveries;
  final int totalDeliveries;

  const DriverStats({
    required this.availableOrders,
    required this.assignedOrders,
    required this.activeDeliveries,
    required this.totalDeliveries,
  });

  factory DriverStats.fromOrders({
    required DriverModel driver,
    required List<OrderModel> availableOrders,
    required List<OrderModel> driverOrders,
  }) {
    return DriverStats(
      availableOrders: availableOrders.length,
      assignedOrders: driverOrders.length,
      activeDeliveries: driverOrders.where(isActiveDriverOrder).length,
      totalDeliveries: driver.totalDeliveries,
    );
  }
}

/// 2×2 (or 1×4 on wide screens) stats grid.
class DriverStatsGrid extends StatelessWidget {
  final DriverStats stats;

  const DriverStatsGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= DriverHomeLayout.wideStatsMinWidth ? 4 : 2;

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 82,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              value: stats.availableOrders.toString(),
              label: 'Có thể nhận',
              icon: Icons.inventory_2_rounded,
              color: AppColors.info,
            ),
            _StatCard(
              value: stats.assignedOrders.toString(),
              label: 'Đơn của bạn',
              icon: Icons.local_shipping_rounded,
              color: AppColors.accent,
            ),
            _StatCard(
              value: stats.activeDeliveries.toString(),
              label: 'Đang giao',
              icon: Icons.route_rounded,
              color: AppColors.warning,
            ),
            _StatCard(
              value: stats.totalDeliveries.toString(),
              label: 'Đã giao',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.lg,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.lg,
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: AppShadow.subtle,
        ),
        child: Row(
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Container(
                color: color.withValues(alpha: 0.035),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: AppRadius.md,
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
