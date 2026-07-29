import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';

class DashboardOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final bool showDivider;

  const DashboardOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final statusLabel = _statusLabel(order.status);

    return Semantics(
      button: true,
      label:
          '${order.deliveryAddress}, $statusLabel, ${_displayOrderCode(order)}',
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.accent.withValues(alpha: 0.06),
        highlightColor: AppColors.accent.withValues(alpha: 0.03),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  _statusIcon(order.status),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${_displayOrderCode(order)} · ${_timeAgo(order.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      statusLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayOrderCode(OrderModel order) {
  if (order.trackingCode.isNotEmpty) return order.trackingCode;
  final length = order.id.length >= 8 ? 8 : order.id.length;
  return '#${order.id.substring(0, length).toUpperCase()}';
}

String _statusLabel(String status) => switch (status) {
  'pending' => 'Chờ xác nhận',
  'confirmed' => 'Đã xác nhận',
  'assigned' => 'Đã có tài xế',
  'picking_up' => 'Đang lấy hàng',
  'delivering' => 'Đang giao',
  'delivered' => 'Đã giao',
  'cancelled' => 'Đã huỷ',
  _ => 'Đang cập nhật',
};

Color _statusColor(String status) => switch (status) {
  'pending' => AppColors.warning,
  'confirmed' || 'assigned' => AppColors.info,
  'picking_up' || 'delivering' => AppColors.accent,
  'delivered' => AppColors.success,
  'cancelled' => AppColors.error,
  _ => AppColors.textSecondary,
};

IconData _statusIcon(String status) => switch (status) {
  'pending' => Icons.schedule_rounded,
  'confirmed' => Icons.check_circle_outline_rounded,
  'assigned' => Icons.person_pin_circle_rounded,
  'picking_up' => Icons.inventory_2_outlined,
  'delivering' => Icons.local_shipping_outlined,
  'delivered' => Icons.check_rounded,
  'cancelled' => Icons.close_rounded,
  _ => Icons.more_horiz_rounded,
};

String _timeAgo(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inSeconds < 60) return 'Vừa xong';
  if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
  if (difference.inHours < 24) return '${difference.inHours} giờ trước';
  if (difference.inDays < 7) return '${difference.inDays} ngày trước';
  if (difference.inDays < 30) {
    return '${(difference.inDays / 7).floor()} tuần trước';
  }
  return '${(difference.inDays / 30).floor()} tháng trước';
}
