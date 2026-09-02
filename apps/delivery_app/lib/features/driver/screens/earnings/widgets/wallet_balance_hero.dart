import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/driver_wallet.dart';
import '../../../../../core/utils/money_formatter.dart';

class WalletBalanceHero extends StatelessWidget {
  const WalletBalanceHero({
    super.key,
    required this.summary,
    required this.todayIncome,
    required this.onTopUp,
  });

  final DriverWalletSummary summary;
  final int todayIncome;
  final VoidCallback onTopUp;

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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'VÍ TÀI XẾ',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Số dư khả dụng',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatVnd(summary.availableBalance),
            style: AppTextStyles.displayLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  icon: Icons.lock_clock_rounded,
                  label: 'Đang giữ',
                  value: formatVnd(summary.heldBalance),
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.today_rounded,
                  label: 'Thu nhập hôm nay',
                  value: '+${formatVnd(todayIncome)}',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 50,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.account_balance_rounded),
                    label: const Text('Rút'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.36),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.full,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onTopUp,
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Nạp qua VNPAY'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textOnAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.full,
                      ),
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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.accent;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgWarm,
        borderRadius: AppRadius.lg,
        border: Border.all(color: foreground.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
