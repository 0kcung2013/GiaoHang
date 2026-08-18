import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../utils/create_order_formatters.dart';
import '../utils/order_form_data.dart';
import 'confirmation_components.dart';

class OrderFinanceSummary extends StatelessWidget {
  const OrderFinanceSummary({super.key, required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    final finance = data.finance;
    const color = AppColors.accent;
    return ConfirmationCard(
      backgroundColor: color.withValues(alpha: 0.06),
      borderColor: color.withValues(alpha: 0.2),
      children: [
        Row(
          children: [
            Icon(Icons.payments_rounded, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'THU TIỀN HỘ (COD)',
                style: AppTextStyles.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _MoneyLine(
          label: 'Tài xế ứng cho người gửi',
          amount: finance.driverAdvanceAmount,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MoneyLine(label: 'Phí giao hàng', amount: finance.deliveryFee),
        const Divider(height: AppSpacing.xl2, color: AppColors.border),
        _MoneyLine(
          label: 'Người nhận cần trả',
          amount: finance.receiverCollectionAmount,
          emphasized: true,
          color: color,
        ),
      ],
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.label,
    required this.amount,
    this.emphasized = false,
    this.color = AppColors.textPrimary,
  });

  final String label;
  final int amount;
  final bool emphasized;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          formatDeliveryFee(amount.toDouble()),
          style:
              (emphasized
                      ? AppTextStyles.headingSmall
                      : AppTextStyles.labelMedium)
                  .copyWith(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
