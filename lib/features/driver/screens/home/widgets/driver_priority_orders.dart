import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_order_card.dart';

/// Shows up to 2 priority orders on the dashboard.
///
/// Priority: active deliveries first, then available orders.
class DriverPriorityOrders extends ConsumerWidget {
  final List<OrderModel> availableOrders;
  final List<OrderModel> driverOrders;
  final String driverUserId;

  const DriverPriorityOrders({
    super.key,
    required this.availableOrders,
    required this.driverOrders,
    required this.driverUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrders =
        driverOrders.where(isActiveDriverOrder).toList();
    final priorityList = <_PriorityOrder>[];

    for (final o in activeOrders.take(2)) {
      priorityList.add(_PriorityOrder(order: o, isActive: true));
    }
    final remaining = 2 - priorityList.length;
    if (remaining > 0) {
      for (final o in availableOrders.take(remaining)) {
        priorityList.add(_PriorityOrder(order: o, isActive: false));
      }
    }

    if (priorityList.isEmpty) {
      return const _EmptyPriorityCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ưu tiên',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${priorityList.length} đơn',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...priorityList.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: DriverOrderCard(
              order: p.order,
              acceptDriverId: p.isActive ? null : driverUserId,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriorityOrder {
  final OrderModel order;
  final bool isActive;

  const _PriorityOrder({required this.order, required this.isActive});
}

class _EmptyPriorityCard extends StatelessWidget {
  const _EmptyPriorityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: AppColors.info,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Chưa có đơn ưu tiên',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bật trạng thái sẵn sàng để nhận đơn mới.',
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
