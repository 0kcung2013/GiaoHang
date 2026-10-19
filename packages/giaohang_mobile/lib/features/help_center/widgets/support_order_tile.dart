import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/models/order_model.dart';
import '../data/help_center_orders.dart';

class SupportOrderTile extends StatelessWidget {
  const SupportOrderTile({
    required this.order,
    required this.onTap,
    this.loading = false,
    super.key,
  });
  final OrderModel order;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.lg,
      side: BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_rounded, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.trackingCode, style: AppTextStyles.mono),
                  Text(
                    helpOrderStatus(order.status),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${order.pickupAddress} → ${order.deliveryAddress}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    ),
  );
}
