import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../../core/models/order_model.dart';
import '../order_detail_strings.dart';
import 'order_detail_header.dart';

class OrderDetailSectionSurface extends StatelessWidget {
  const OrderDetailSectionSurface({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(icon, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class OrderDetailRouteCard extends StatelessWidget {
  const OrderDetailRouteCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionSurface(
      title: OrderDetailStrings.routeTitle,
      icon: Icons.route_rounded,
      child: Column(
        children: [
          _RouteStop(
            color: AppColors.markerPickup,
            icon: Icons.storefront_rounded,
            label: OrderDetailStrings.pickup,
            value: _fallback(order.pickupAddress),
            showConnector: true,
          ),
          _RouteStop(
            color: AppColors.markerDrop,
            icon: Icons.location_on_rounded,
            label: OrderDetailStrings.delivery,
            value: _fallback(order.deliveryAddress),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.lg,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        OrderDetailStrings.recipient,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        _fallback(order.recipientName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    _fallback(order.recipientPhone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderDetailPaymentCard extends StatelessWidget {
  const OrderDetailPaymentCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final items = [
      _PaymentInfo(
        icon: Icons.local_shipping_outlined,
        label: OrderDetailStrings.service,
        value: _serviceTypeLabel(order.serviceType),
      ),
      _PaymentInfo(
        icon: Icons.payments_outlined,
        label: OrderDetailStrings.payment,
        value: _paymentMethodLabel(order.paymentMethod),
      ),
      _PaymentInfo(
        icon: Icons.receipt_long_outlined,
        label: OrderDetailStrings.deliveryFee,
        value: formatOrderMoney(order.deliveryFee),
      ),
      _PaymentInfo(
        icon: Icons.account_balance_wallet_outlined,
        label: OrderDetailStrings.total,
        value: formatOrderMoney(order.totalPrice ?? order.deliveryFee),
        emphasized: true,
      ),
    ];

    return OrderDetailSectionSurface(
      title: OrderDetailStrings.paymentTitle,
      icon: Icons.wallet_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemWidth,
                  child: _PaymentInfoTile(info: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class OrderDetailNoteCard extends StatelessWidget {
  const OrderDetailNoteCard({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionSurface(
      title: OrderDetailStrings.noteTitle,
      icon: Icons.sticky_note_2_outlined,
      child: Text(
        note,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    this.showConnector = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (showConnector)
                Container(
                  width: 2,
                  height: 42,
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: showConnector ? AppSpacing.md : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentInfo {
  const _PaymentInfo({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;
}

class _PaymentInfoTile extends StatelessWidget {
  const _PaymentInfoTile({required this.info});

  final _PaymentInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: info.emphasized ? AppColors.accentLight : AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: info.emphasized
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            info.icon,
            size: 18,
            color: info.emphasized ? AppColors.accent : AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            info.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            info.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: info.emphasized ? AppColors.accent : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _fallback(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? OrderDetailStrings.noData : text;
}

String _serviceTypeLabel(String value) {
  return switch (value) {
    'express' => 'Hỏa tốc',
    'fragile' => 'Dễ vỡ',
    'document' => 'Tài liệu',
    _ => 'Tiêu chuẩn',
  };
}

String _paymentMethodLabel(String value) {
  return switch (value) {
    'card' => 'Thẻ',
    'wallet' => 'Ví điện tử',
    _ => 'Tiền mặt',
  };
}
