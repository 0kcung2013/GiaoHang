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
    this.orderStatus = 'assigned',
    this.hasPickedUp = false,
    super.key,
  });

  final RiskReporterRole role;
  final RiskCategory? selected;
  final String? errorText;
  final ValueChanged<RiskCategory> onSelected;
  final String orderStatus;
  final bool hasPickedUp;

  @override
  Widget build(BuildContext context) {
    final options = riskOptionsFor(
      role,
      orderStatus: orderStatus,
      hasPickedUp: hasPickedUp,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chọn vấn đề', style: AppTextStyles.headingMedium),
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
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.md,
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
