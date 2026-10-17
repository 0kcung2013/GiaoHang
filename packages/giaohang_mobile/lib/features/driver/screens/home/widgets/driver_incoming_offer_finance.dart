import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../driver_home_strings.dart';

/// COD và khoản giữ ví lấy từ snapshot tài chính, tách khỏi thu nhập.
class DriverIncomingOfferFinance extends StatelessWidget {
  const DriverIncomingOfferFinance({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: const BoxDecoration(
      color: AppColors.bgLight,
      borderRadius: AppRadius.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FinanceRow(
          icon: Icons.payments_outlined,
          label: order.codCollectionAmount > 0
              ? DriverHomeStrings.incomingOfferCod
              : DriverHomeStrings.incomingOfferNoCod,
          amount: order.codCollectionAmount > 0
              ? formatVnd(order.codCollectionAmount)
              : null,
        ),
        if (order.driverAdvanceAmount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _FinanceRow(
            icon: Icons.account_balance_wallet_outlined,
            label: DriverHomeStrings.incomingOfferWalletHold,
            amount: formatVnd(order.driverAdvanceAmount),
          ),
        ],
      ],
    ),
  );
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({required this.icon, required this.label, this.amount});

  final IconData icon;
  final String label;
  final String? amount;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (amount != null)
              Text(
                amount!,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
