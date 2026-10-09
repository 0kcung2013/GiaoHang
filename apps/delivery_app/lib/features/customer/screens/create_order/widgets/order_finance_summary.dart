import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../utils/order_form_data.dart';
import '../utils/order_payment_strings.dart';
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
                finance.receiverCollectionAmount == 0
                    ? OrderPaymentText.noCollection
                    : OrderPaymentText.collect,
                style: AppTextStyles.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (finance.codCollectionAmount > 0) ...[
          _MoneyLine(
            label: OrderPaymentText.goods,
            amount: finance.codCollectionAmount,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (finance.codCollectionAmount == 0 && finance.goodsValue > 0) ...[
          _MoneyLine(
            label: OrderPaymentText.goodsDeposit,
            amount: finance.goodsValue,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _MoneyLine(label: 'Phí giao hàng', amount: finance.deliveryFee),
        const Divider(height: AppSpacing.xl2, color: AppColors.border),
        _MoneyLine(
          label: OrderPaymentText.total,
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
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            formatVnd(amount),
            style:
                (emphasized
                        ? AppTextStyles.headingSmall
                        : AppTextStyles.labelMedium)
                    .copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
