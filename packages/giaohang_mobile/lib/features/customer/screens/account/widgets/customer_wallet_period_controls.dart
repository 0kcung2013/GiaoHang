import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../utils/customer_wallet_period.dart';

class CustomerWalletPeriodControls extends StatelessWidget {
  const CustomerWalletPeriodControls({
    super.key,
    required this.selection,
    required this.today,
    required this.onPeriodChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final CustomerWalletPeriodSelection selection;
  final DateTime today;
  final ValueChanged<CustomerWalletPeriod> onPeriodChanged;
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
              for (final period in CustomerWalletPeriod.values)
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
            decoration: const BoxDecoration(
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
                    label:
                        'Chọn ngày, '
                        '${customerWalletPeriodLabel(selection, today)}',
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
                                  customerWalletPeriodLabel(selection, today),
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

class CustomerWalletPeriodSummary extends StatelessWidget {
  const CustomerWalletPeriodSummary({
    super.key,
    required this.transactionCount,
    required this.receivedText,
    required this.spentText,
  });

  final int transactionCount;
  final String receivedText;
  final String spentText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Kỳ đã chọn, tiền vào $receivedText, tiền ra $spentText, '
          '$transactionCount giao dịch',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgWarm,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _FlowMetric(
                icon: Icons.south_west_rounded,
                label: 'Tiền vào',
                value: receivedText,
                color: AppColors.success,
              ),
            ),
            Container(width: 1, height: 44, color: AppColors.border),
            Expanded(
              child: _FlowMetric(
                icon: Icons.north_east_rounded,
                label: 'Tiền ra',
                value: spentText,
                color: AppColors.error,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: AppRadius.full,
              ),
              child: Text(
                '$transactionCount GD',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowMetric extends StatelessWidget {
  const _FlowMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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

  final CustomerWalletPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (period) {
      CustomerWalletPeriod.day => 'Ngày',
      CustomerWalletPeriod.week => 'Tuần',
      CustomerWalletPeriod.month => 'Tháng',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Xem theo $label',
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
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
                      ? AppColors.textOnAccent
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

String customerWalletPeriodLabel(
  CustomerWalletPeriodSelection selection,
  DateTime today,
) {
  String two(int value) => value.toString().padLeft(2, '0');
  final start = selection.start;
  final todayDate = DateTime(today.year, today.month, today.day);
  if (selection.period == CustomerWalletPeriod.day) {
    if (start == todayDate) return 'Hôm nay';
    return '${two(start.day)}/${two(start.month)}/${start.year}';
  }
  if (selection.period == CustomerWalletPeriod.month) {
    return 'Tháng ${two(start.month)}/${start.year}';
  }
  final end = selection.endExclusive.subtract(const Duration(days: 1));
  return '${two(start.day)}/${two(start.month)} – '
      '${two(end.day)}/${two(end.month)}';
}
