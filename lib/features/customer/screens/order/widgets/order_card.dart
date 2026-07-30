import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../order_helpers.dart';
import 'order_card_content.dart';

const orderCardSurfaceKey = Key('order-card-surface');
const orderCardStatusRailKey = Key('order-card-status-rail');

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.isFeatured = false,
  });

  final OrderModel order;
  final VoidCallback onTap;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    final status = OrderStatusView.fromStatus(
      order.effectiveStatusAt(DateTime.now()),
    );
    final code = order.trackingCode.trim().isEmpty
        ? order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)
        : order.trackingCode.trim();

    return Semantics(
      button: true,
      label: 'Xem đơn $code, ${status.label}',
      child: DecoratedBox(
        key: orderCardSurfaceKey,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          border: Border.all(
            color: isFeatured
                ? AppColors.accent.withValues(alpha: 0.58)
                : AppColors.primary.withValues(alpha: 0.14),
            width: isFeatured ? 1.4 : 1,
          ),
          boxShadow: isFeatured
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : AppShadow.card,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.xl,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.accent.withValues(alpha: 0.08),
            highlightColor: AppColors.accent.withValues(alpha: 0.04),
            child: Stack(
              children: [
                OrderCardContent(order: order),
                Positioned(
                  key: orderCardStatusRailKey,
                  left: 0,
                  top: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: status.color,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: const SizedBox(width: 4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
