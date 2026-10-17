import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_finance.dart';
import 'create_order_inputs.dart';

class OrderPaymentMethodSection extends StatelessWidget {
  const OrderPaymentMethodSection({
    super.key,
    required this.deliveryFeePayer,
    required this.onDeliveryFeePayerChanged,
  });

  final DeliveryFeePayer deliveryFeePayer;
  final ValueChanged<DeliveryFeePayer> onDeliveryFeePayerChanged;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      step: '04',
      icon: Icons.account_balance_wallet_outlined,
      title: 'Phương thức thanh toán',
      accentColor: AppColors.accent,
      subtitle: 'Chọn người thanh toán phí giao hàng',
      children: [
        _PaymentModeCard(
          label: 'Thanh toán qua VNPAY',
          description: 'Người tạo đơn trả phí giao hàng',
          icon: Icons.account_balance_rounded,
          color: AppColors.success,
          selected: deliveryFeePayer == DeliveryFeePayer.sender,
          onTap: () => onDeliveryFeePayerChanged(DeliveryFeePayer.sender),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PaymentModeCard(
          label: 'Thanh toán khi nhận hàng',
          description: 'Người nhận trả phí giao và giá kiện hàng',
          icon: Icons.payments_rounded,
          color: AppColors.accent,
          selected: deliveryFeePayer == DeliveryFeePayer.recipient,
          onTap: () => onDeliveryFeePayerChanged(DeliveryFeePayer.recipient),
        ),
      ],
    );
  }
}

class _PaymentModeCard extends StatelessWidget {
  const _PaymentModeCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: description,
      child: Material(
        color: selected ? color.withValues(alpha: 0.08) : AppColors.bgLight,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: selected ? color : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? color : AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
