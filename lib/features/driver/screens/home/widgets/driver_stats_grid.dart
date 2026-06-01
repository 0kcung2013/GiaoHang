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

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: crossAxisCount == 4 ? 1.28 : 1.2,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
