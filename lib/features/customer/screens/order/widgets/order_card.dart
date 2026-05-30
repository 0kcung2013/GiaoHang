import 'package:flutter/material.dart';

import 'order_theme.dart';
import 'order_vm.dart';

class OrderCard extends StatelessWidget {
  final OrderVm order;
  final String actionLabel;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = _statusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(OrderSpacing.lg),
      decoration: BoxDecoration(
        color: OrderColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: OrderShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderCode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OrderColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: OrderSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: OrderSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: OrderSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: OrderColors.accentLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.packageType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: OrderColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: OrderSpacing.sm),
              Expanded(
                child: Text(
                  order.priceText,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OrderColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: OrderSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                children: [
                  Icon(
                    Icons.radio_button_checked_rounded,
                    size: 14,
                    color: OrderColors.markerPickup,
                  ),
                  SizedBox(
                    height: 30,
                    child: VerticalDivider(
                      width: 20,
                      thickness: 1.2,
                      color: OrderColors.border,
                    ),
                  ),
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: OrderColors.markerDrop,
                  ),
                ],
              ),
              const SizedBox(width: OrderSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.pickupAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: OrderColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: OrderSpacing.md),
                    Text(
                      order.deliveryAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: OrderColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OrderSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: OrderColors.textMuted,
              ),
              const SizedBox(width: OrderSpacing.xs),
              Expanded(
                child: Text(
                  order.timeText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: OrderColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: OrderColors.primary,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: OrderSpacing.sm),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Đang lấy hàng':
        return OrderColors.accent;
      case 'Đang giao':
        return OrderColors.info;
      case 'Hoàn thành':
        return OrderColors.success;
      case 'Đã hủy':
        return OrderColors.error;
      default:
        return OrderColors.warning;
    }
  }
}