import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/driver_wallet.dart';
import '../../../../../core/utils/money_formatter.dart';

class WalletBalanceHero extends StatelessWidget {
  const WalletBalanceHero({
    super.key,
    required this.summary,
    required this.onTopUp,
    this.onWithdraw,
  });

  final DriverWalletSummary summary;
  final VoidCallback onTopUp;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('driver_wallet_balance_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl2,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'VÍ TÀI XẾ',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgWarm,
                  borderRadius: AppRadius.full,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  'Giữ ${formatVnd(summary.heldBalance)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Số dư khả dụng',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatVnd(summary.availableBalance),
              style: AppTextStyles.displayLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.account_balance_rounded, size: 19),
                  label: const Text('Rút tiền'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    disabledForegroundColor: AppColors.textMuted,
                    side: BorderSide(
                      color: onWithdraw == null
                          ? AppColors.border
                          : AppColors.accent.withValues(alpha: 0.36),
                    ),
                    minimumSize: const Size.fromHeight(50),
                    textStyle: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onTopUp,
                  icon: const Icon(Icons.add_card_rounded, size: 19),
                  label: const Text('Nạp tiền'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    minimumSize: const Size.fromHeight(50),
                    textStyle: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
