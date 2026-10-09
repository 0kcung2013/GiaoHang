import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../utils/create_order_formatters.dart';
import '../utils/order_payment_strings.dart';

class OrderPaymentPendingCard extends StatelessWidget {
  const OrderPaymentPendingCard({
    super.key,
    required this.amount,
    required this.expiresAt,
    required this.onCheck,
    this.isChecking = false,
    this.error,
  });

  final int amount;
  final DateTime expiresAt;
  final VoidCallback onCheck;
  final bool isChecking;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now());
    final minutes = remaining.isNegative ? 0 : remaining.inMinutes + 1;
    return Semantics(
      liveRegion: true,
      label: 'Đang chờ VNPAY xác nhận thanh toán',
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          0,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.info.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: AppRadius.md,
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        OrderPaymentText.awaitingPayment,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${formatDeliveryFee(amount.toDouble())} · còn khoảng $minutes phút',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.sync_rounded, color: AppColors.info, size: 22),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isChecking ? null : onCheck,
                style: TextButton.styleFrom(foregroundColor: AppColors.info),
                child: Text(
                  isChecking
                      ? OrderPaymentText.checkingPayment
                      : OrderPaymentText.checkPayment,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
