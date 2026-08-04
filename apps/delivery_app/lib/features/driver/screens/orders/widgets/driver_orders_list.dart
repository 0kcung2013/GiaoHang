import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../home/widgets/driver_order_card.dart';
import '../../home/widgets/driver_state_widgets.dart';
import '../utils/driver_order_filter.dart';

class DriverOrdersList extends StatelessWidget {
  final DriverOrderFilter filter;
  final List<OrderModel> orders;
  final String? acceptDriverId;

  const DriverOrdersList({
    super.key,
    required this.filter,
    required this.orders,
    this.acceptDriverId,
  });

  @override
  Widget build(BuildContext context) {
    return DriverSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    filter.title,
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _CountPill(count: orders.length),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (orders.isEmpty)
              _EmptyOrdersState(filter: filter)
            else
              ...orders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DriverOrderCard(
                    order: order,
                    acceptDriverId: acceptDriverId,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;

  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        count.toString(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.info,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  final DriverOrderFilter filter;

  const _EmptyOrdersState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.info,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filter.emptyTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            filter.emptyMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
