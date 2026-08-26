import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/money_formatter.dart';

Future<void> showDriverWalletDebitDialog({
  required BuildContext context,
  required int debitedAmount,
  required int? availableBalance,
}) {
  final balanceLabel = availableBalance == null
      ? 'Đang cập nhật'
      : formatVnd(availableBalance);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl2),
      child: Semantics(
        liveRegion: true,
        label:
            'Đã trừ ${formatVnd(debitedAmount)}. '
            'Số dư khả dụng $balanceLabel.',
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(AppSpacing.xl2),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.xl2,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.xl,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'ĐÃ ỨNG TIỀN HÀNG',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '−${formatVnd(debitedAmount)}',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'Số dư khả dụng',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      balanceLabel,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                  ),
                  child: Text(
                    'Tiếp tục giao hàng',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textOnAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
