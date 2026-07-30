import 'package:flutter/material.dart';

import '../../../../../../core/constants/app_theme.dart';
import '../../../../../../core/models/order_model.dart';
import '../../../../../../core/utils/order_cargo_utils.dart';
import '../../order_helpers.dart';
import '../../widgets/order_card_image.dart';
import '../order_detail_strings.dart';

const orderDetailSummaryKey = Key('order-detail-summary');
const orderDetailCargoKey = Key('order-detail-cargo');

class OrderDetailSheetHeader extends StatelessWidget {
  const OrderDetailSheetHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            OrderDetailStrings.screenTitle,
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Material(
          color: AppColors.accentLight,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onClose,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.close_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OrderDetailSummaryCard extends StatelessWidget {
  const OrderDetailSummaryCard({
    super.key,
    required this.order,
    required this.status,
  });

  final OrderModel order;
  final OrderStatusView status;

  @override
  Widget build(BuildContext context) {
    final displayId = order.trackingCode.trim().isNotEmpty
        ? order.trackingCode.trim()
        : '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}';

    return Container(
      key: orderDetailSummaryKey,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(status.icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mono.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      formatOrderDateTime(order.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: AppColors.accent.withValues(alpha: 0.14)),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  OrderDetailStrings.total,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                formatOrderMoney(order.totalPrice ?? order.deliveryFee),
                style: AppTextStyles.headingLarge.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if ((order.statusNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.md,
              ),
              child: Text(
                order.statusNote!.trim(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OrderDetailCargoCard extends StatelessWidget {
  const OrderDetailCargoCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final description = order.itemDescription?.trim();

    return Container(
      key: orderDetailCargoKey,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            OrderDetailStrings.cargoTitle,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderCardImage(
                imageUrl: order.itemImageUrl,
                category: order.itemCategory,
                size: 104,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cargoNameOrFallback(order),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: AppRadius.full,
                      ),
                      child: Text(
                        cargoCategoryLabel(order.itemCategory).toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OrderStatusView status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: status.color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

String formatOrderMoney(double amount) {
  if (amount <= 0) return OrderDetailStrings.noFee;
  final value = amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
  return '$value\u0111';
}
