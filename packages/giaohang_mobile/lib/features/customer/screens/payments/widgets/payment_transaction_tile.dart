import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show formatVnd;

import '../dialogs/payment_detail_sheet.dart';
import '../models/customer_payment.dart';
import '../utils/payment_format.dart';

class PaymentTransactionTile extends StatelessWidget {
  const PaymentTransactionTile({super.key, required this.payment});
  final CustomerPayment payment;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.lg,
      side: BorderSide(color: AppColors.border),
    ),
    child: InkWell(
      onTap: () => showCustomerPaymentDetail(context, payment),
      borderRadius: AppRadius.lg,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  payment.method == CustomerPaymentMethod.wallet
                      ? Icons.account_balance_wallet_rounded
                      : Icons.payment_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    payment.method.label,
                    style: AppTextStyles.labelMedium,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  formatVnd(payment.amount),
                  style: AppTextStyles.headingSmall,
                ),
                Text(
                  payment.state.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              payment.trackingCode ?? payment.reference,
              style: AppTextStyles.mono,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              customerPaymentDate(payment.createdAt),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
