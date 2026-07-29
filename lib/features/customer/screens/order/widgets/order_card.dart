import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../order_helpers.dart';

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
    final status = OrderStatusView.fromStatus(order.status);
    final price = order.totalPrice ?? order.deliveryFee;
    final displayCode = order.trackingCode.isNotEmpty
        ? order.trackingCode
        : '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}';

    return Material(
      color: isFeatured ? AppColors.primary : AppColors.bgCard,
      borderRadius: AppRadius.xl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xl,
        splashColor: isFeatured
            ? AppColors.textOnDark.withValues(alpha: 0.08)
            : AppColors.accent.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.xl,
            border: isFeatured
                ? null
                : Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(status: status, darkSurface: isFeatured),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    displayCode,
                    style: AppTextStyles.mono.copyWith(
                      color: isFeatured
                          ? AppColors.textOnDark.withValues(alpha: 0.78)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeAgo(order.createdAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isFeatured
                          ? AppColors.textOnDark.withValues(alpha: 0.62)
                          : AppColors.textMuted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _RouteLine(
                icon: Icons.radio_button_checked_rounded,
                color: AppColors.markerPickup,
                label: 'Lấy hàng',
                address: order.pickupAddress,
                darkSurface: isFeatured,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 9),
                child: SizedBox(
                  height: 14,
                  child: VerticalDivider(
                    width: 2,
                    thickness: 2,
                    color: AppColors.border,
                  ),
                ),
              ),
              _RouteLine(
                icon: Icons.location_on_rounded,
                color: AppColors.markerDrop,
                label: 'Giao đến',
                address: order.deliveryAddress,
                darkSurface: isFeatured,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                height: 1,
                color: isFeatured
                    ? AppColors.textOnDark.withValues(alpha: 0.12)
                    : AppColors.border,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: isFeatured
                        ? AppColors.textOnDark.withValues(alpha: 0.68)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      order.recipientName?.trim().isNotEmpty == true
                          ? order.recipientName!.trim()
                          : 'Người nhận chưa cập nhật',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isFeatured
                            ? AppColors.textOnDark.withValues(alpha: 0.8)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    _formatPrice(price),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isFeatured
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isFeatured
                        ? AppColors.textOnDark.withValues(alpha: 0.7)
                        : AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
    required this.darkSurface,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String address;
  final bool darkSurface;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: darkSurface
                      ? AppColors.textOnDark.withValues(alpha: 0.58)
                      : AppColors.textMuted,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address.isEmpty ? 'Chưa cập nhật địa chỉ' : address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: darkSurface
                      ? AppColors.textOnDark
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.darkSurface});

  final OrderStatusView status;
  final bool darkSurface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: darkSurface
            ? status.color.withValues(alpha: 0.22)
            : status.color.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: darkSurface ? AppColors.textOnDark : status.color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
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
  return '$valueđ';
}

String timeAgo(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inSeconds < 60) return 'Vừa xong';
  if (difference.inMinutes < 60) return '${difference.inMinutes}p';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays} ngày';
  return '${(difference.inDays / 7).floor()} tuần';
}
