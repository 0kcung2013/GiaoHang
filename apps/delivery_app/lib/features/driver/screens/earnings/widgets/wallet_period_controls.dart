import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../utils/driver_wallet_period.dart';

class WalletPeriodControls extends StatelessWidget {
  const WalletPeriodControls({
    super.key,
    required this.selection,
    required this.today,
    required this.onPeriodChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final DriverWalletPeriodSelection selection;
  final DateTime today;
  final ValueChanged<DriverWalletPeriod> onPeriodChanged;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final period in DriverWalletPeriod.values)
                Expanded(
                  child: _PeriodOption(
                    period: period,
                    selected: selection.period == period,
                    onTap: () => onPeriodChanged(period),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: AppRadius.lg,
            ),
            child: Row(
              children: [
                _NavigationButton(
                  tooltip: 'Kỳ trước',
                  icon: Icons.chevron_left_rounded,
                  onTap: onPrevious,
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Chọn ngày, ${walletPeriodLabel(selection, today)}',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPickDate,
                        borderRadius: AppRadius.md,
                        child: SizedBox(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 19,
                                color: AppColors.info,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  walletPeriodLabel(selection, today),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _NavigationButton(
                  tooltip: 'Kỳ sau',
                  icon: Icons.chevron_right_rounded,
                  onTap: onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WalletPeriodSummary extends StatelessWidget {
  const WalletPeriodSummary({
    super.key,
    required this.transactionCount,
    required this.incomeText,
  });

  final int transactionCount;
  final String incomeText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Thu nhập kỳ đã chọn $incomeText, $transactionCount giao dịch',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.success.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.14),
                borderRadius: AppRadius.md,
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thu nhập kỳ đã chọn',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    incomeText,
                    style: AppTextStyles.headingLarge.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: AppRadius.full,
              ),
              child: Text(
                '$transactionCount giao dịch',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodOption extends StatelessWidget {
  const _PeriodOption({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final DriverWalletPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (period) {
      DriverWalletPeriod.day => 'Ngày',
      DriverWalletPeriod.week => 'Tuần',
      DriverWalletPeriod.month => 'Tháng',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Xem theo $label',
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.textOnDark
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Icon(icon, color: AppColors.textSecondary),
    );
  }
}

String walletPeriodLabel(
  DriverWalletPeriodSelection selection,
  DateTime today,
) {
  String two(int value) => value.toString().padLeft(2, '0');
  final start = selection.start;
  final todayDate = DateTime(today.year, today.month, today.day);
  if (selection.period == DriverWalletPeriod.day) {
    if (start == todayDate) return 'Hôm nay';
    return '${two(start.day)}/${two(start.month)}/${start.year}';
  }
  if (selection.period == DriverWalletPeriod.month) {
    return 'Tháng ${two(start.month)}/${start.year}';
  }
  final end = selection.endExclusive.subtract(const Duration(days: 1));
  return '${two(start.day)}/${two(start.month)} – '
      '${two(end.day)}/${two(end.month)}';
}
