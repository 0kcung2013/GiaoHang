import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../models/support_order.dart';
import '../utils/support_order_ui.dart';

class SupportOrderCard extends StatelessWidget {
  const SupportOrderCard({required this.order, required this.onTap, super.key});

  final SupportOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = SupportOrderUi.statusColor(order.status);
    return Semantics(
      button: true,
      label: 'Mở chi tiết đơn ${order.trackingCode}',
      child: Material(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: AppRadius.lg,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.subtle,
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: statusColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OrderCardHeader(order: order, color: statusColor),
                          const SizedBox(height: AppSpacing.md),
                          _RoutePanel(order: order),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.xl,
                            runSpacing: AppSpacing.sm,
                            children: [
                              _InlineInfo(
                                icon: Icons.person_outline_rounded,
                                text:
                                    order.recipientName?.trim().isNotEmpty ==
                                        true
                                    ? order.recipientName!
                                    : 'Chưa có người nhận',
                              ),
                              _InlineInfo(
                                icon: Icons.payments_outlined,
                                text: formatVnd(order.totalPrice),
                              ),
                              _InlineInfo(
                                icon: Icons.schedule_rounded,
                                text: SupportOrderUi.formatDateTime(
                                  order.createdAt,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCardHeader extends StatelessWidget {
  const _OrderCardHeader({required this.order, required this.color});

  final SupportOrder order;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.sm,
          ),
          child: const Icon(Icons.inventory_2_rounded, color: AppColors.accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.trackingCode,
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                order.recipientName?.trim().isNotEmpty == true
                    ? 'Người nhận: ${order.recipientName}'
                    : 'Người nhận chưa cập nhật',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.full,
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Text(
            SupportOrderUi.statusLabel(order.status),
            style: AppTextStyles.labelSmall.copyWith(color: color),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      ],
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({required this.order});

  final SupportOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _RouteLine(
            icon: Icons.radio_button_checked_rounded,
            color: AppColors.markerPickup,
            address: order.pickupAddress,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 14,
                child: VerticalDivider(width: 1, color: AppColors.border),
              ),
            ),
          ),
          _RouteLine(
            icon: Icons.location_on_rounded,
            color: AppColors.markerDrop,
            address: order.deliveryAddress,
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
