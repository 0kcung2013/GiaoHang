import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_order_card.dart';

/// Hiển thị tối đa hai đơn ưu tiên trên dashboard.
///
/// Đơn đang thực hiện luôn đứng trước. Đơn có thể nhận được xếp theo khoảng
/// cách đến điểm lấy hàng nếu đã có vị trí tài xế.
class DriverPriorityOrders extends StatelessWidget {
  const DriverPriorityOrders({
    super.key,
    required this.availableOrders,
    required this.driverOrders,
    required this.driverUserId,
    this.pickupDistancesMeters = const {},
  });

  final List<OrderModel> availableOrders;
  final List<OrderModel> driverOrders;
  final String driverUserId;
  final Map<String, double> pickupDistancesMeters;

  @override
  Widget build(BuildContext context) {
    final activeOrders = driverOrders.where(isActiveDriverOrder).toList();
    final sortedAvailable = [...availableOrders]
      ..sort((left, right) {
        final leftDistance = pickupDistancesMeters[left.id];
        final rightDistance = pickupDistancesMeters[right.id];
        if (leftDistance == null && rightDistance == null) return 0;
        if (leftDistance == null) return 1;
        if (rightDistance == null) return -1;
        return leftDistance.compareTo(rightDistance);
      });

    final priorityList = <_PriorityOrder>[
      for (final order in activeOrders.take(2))
        _PriorityOrder(order: order, isActive: true),
    ];
    final remaining = 2 - priorityList.length;
    if (remaining > 0) {
      priorityList.addAll(
        sortedAvailable
            .take(remaining)
            .map((order) => _PriorityOrder(order: order, isActive: false)),
      );
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
              activeOrders.isNotEmpty ? 'Việc cần làm' : 'Đơn gần bạn',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${priorityList.length} đơn ưu tiên',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...priorityList.map(
          (priority) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: DriverOrderCard(
              order: priority.order,
              acceptDriverId: priority.isActive ? null : driverUserId,
              pickupDistanceMeters: pickupDistancesMeters[priority.order.id],
            ),
          ),
        ),
      ],
    );
  }
}

class _PriorityOrder {
  const _PriorityOrder({required this.order, required this.isActive});

  final OrderModel order;
  final bool isActive;
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
            'Chưa có việc cần xử lý',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bật trạng thái sẵn sàng để hệ thống gửi đơn phù hợp.',
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
