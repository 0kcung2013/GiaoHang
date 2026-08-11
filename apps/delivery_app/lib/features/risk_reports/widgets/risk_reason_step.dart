import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/risk_report_options.dart';

class RiskReasonStep extends StatelessWidget {
  const RiskReasonStep({
    required this.role,
    required this.selected,
    required this.errorText,
    required this.onSelected,
    super.key,
  });

  final RiskReporterRole role;
  final RiskCategory? selected;
  final String? errorText;
  final ValueChanged<RiskCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = riskOptionsFor(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chọn vấn đề', style: AppTextStyles.headingMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Chọn nội dung gần nhất với sự cố.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final option in options) ...[
          _ReasonTile(
            option: option,
            selected: selected == option.category,
            onTap: () => onSelected(option.category),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final RiskReportOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('risk-option-${option.category.databaseValue}'),
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.accentLight : AppColors.bgCard,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.md,
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.bgWarm,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(
                    _iconFor(option.category),
                    color: selected ? AppColors.accent : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label, style: AppTextStyles.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        option.description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(RiskCategory category) => switch (category) {
  RiskCategory.deliveryDelay => Icons.schedule_rounded,
  RiskCategory.suspiciousAddress => Icons.location_off_rounded,
  RiskCategory.contactIssue => Icons.phone_disabled_rounded,
  RiskCategory.cargoIssue => Icons.inventory_2_outlined,
  RiskCategory.payment => Icons.payments_outlined,
  RiskCategory.safety => Icons.health_and_safety_outlined,
  _ => Icons.more_horiz_rounded,
};
