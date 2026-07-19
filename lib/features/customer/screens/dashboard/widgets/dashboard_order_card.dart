import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';

class DashboardOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const DashboardOrderCard({
    super.key,
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        shadowColor: const Color(0x0A000000),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.xl,
          splashColor: AppColors.accent.withValues(alpha: 0.06),
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.xl,
              boxShadow: AppShadow.card,
            ),
            child: Row(
              children: [
                _buildStatusIcon(statusColor),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _buildContent(statusColor)),
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
      ),
    );
  }

  Widget _buildStatusIcon(Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.md,
      ),
      child: Icon(
        _statusIcon(order.status),
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildContent(Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.deliveryAddress,
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_displayOrderCode(order)} · ${_timeAgo(order.createdAt)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusPill(status: order.status, color: statusColor),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        _statusLabel(status),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0,
          height: 1.2,
        ),
      ),
    );
  }
}

String _displayOrderCode(OrderModel order) {
  if (order.trackingCode.isNotEmpty) return order.trackingCode;
  final len = order.id.length >= 8 ? 8 : order.id.length;
  return '#${order.id.substring(0, len)}';
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Đã xác nhận',
    'assigned' => 'Đã phân công',
    'picking_up' => 'Đang lấy',
    'delivering' => 'Đang giao',
    'delivered' => 'Hoàn thành',
    'cancelled' => 'Đã huỷ',
    _ => 'Không rõ',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'pending' => AppColors.warning,
    'confirmed' => AppColors.info,
    'assigned' => AppColors.info,
    'picking_up' => AppColors.accent,
    'delivering' => AppColors.accent,
    'delivered' => AppColors.success,
    'cancelled' => AppColors.error,
    _ => AppColors.textMuted,
  };
}

IconData _statusIcon(String status) {
  return switch (status) {
    'pending' => Icons.access_time_rounded,
    'confirmed' => Icons.check_circle_outline_rounded,
    'assigned' => Icons.local_shipping_rounded,
    'picking_up' => Icons.storefront_rounded,
    'delivering' => Icons.local_shipping_outlined,
    'delivered' => Icons.check_circle_rounded,
    'cancelled' => Icons.cancel_rounded,
    _ => Icons.help_outline_rounded,
  };
}

String _timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} tuần trước';
  return '${(diff.inDays / 30).floor()} tháng trước';
}
