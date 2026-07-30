import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import '../order_helpers.dart';
import 'order_card_image.dart';
import 'order_card_route_panel.dart';

const orderCardDetailAffordanceKey = Key('order-card-detail-affordance');

class OrderCardContent extends StatelessWidget {
  const OrderCardContent({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final status = OrderStatusView.fromStatus(
      order.effectiveStatusAt(DateTime.now()),
    );
    final price = order.totalPrice ?? order.deliveryFee;
    final displayCode = order.trackingCode.isNotEmpty
        ? order.trackingCode
        : '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: _OrderHeader(
            status: status,
            displayCode: displayCode,
            createdAt: order.createdAt,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _CargoSummary(order: order, price: price),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: OrderCardRoutePanel(order: order),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: _RecipientFooter(order: order),
        ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.status,
    required this.displayCode,
    required this.createdAt,
  });

  final OrderStatusView status;
  final String displayCode;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusBadge(status: status),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            displayCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.mono.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(
          Icons.schedule_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _timeAgo(createdAt),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _CargoSummary extends StatelessWidget {
  const _CargoSummary({required this.order, required this.price});

  final OrderModel order;
  final double price;

  @override
  Widget build(BuildContext context) {
    final description = order.itemDescription?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderCardImage(
          imageUrl: order.itemImageUrl,
          category: order.itemCategory,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cargoCategoryLabel(order.itemCategory).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                cargoNameOrFallback(order),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _PriceBadge(price: price),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.payments_outlined,
            color: AppColors.accent,
            size: 15,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _formatPrice(price),
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
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
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.11),
        borderRadius: AppRadius.full,
        border: Border.all(color: status.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientFooter extends StatelessWidget {
  const _RecipientFooter({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final recipient = order.recipientName?.trim();
    final recipientName = recipient == null || recipient.isEmpty
        ? 'Chưa cập nhật'
        : recipient;

    return Semantics(
      label: 'Người nhận: $recipientName',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.09)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                recipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              key: orderCardDetailAffordanceKey,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 21,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(double price) {
  if (price <= 0) return 'Chưa tính phí';
  final value = price
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]!}.',
      );
  return '$value\u0111';
}

String _timeAgo(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inSeconds < 60) return 'Vừa xong';
  if (difference.inMinutes < 60) return '${difference.inMinutes}p';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays} ngày';
  return '${(difference.inDays / 7).floor()} tuần';
}
