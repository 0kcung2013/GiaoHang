import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/risk_report_options.dart';
import '../utils/risk_report_strings.dart';

class RiskReasonStep extends StatefulWidget {
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
  State<RiskReasonStep> createState() => _RiskReasonStepState();
}

class _RiskReasonStepState extends State<RiskReasonStep> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final errorText = widget.errorText;
    final options = riskOptionsFor(widget.role);
    final compact = widget.role == RiskReporterRole.driver;
    final secondary = options
        .where(
          (option) =>
              option.category == RiskCategory.payment ||
              option.category == RiskCategory.other,
        )
        .toList();
    final primary = compact
        ? options.where((option) => !secondary.contains(option)).toList()
        : options;
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
        for (final option in primary) ...[
          _ReasonTile(
            option: option,
            selected: selected == option.category,
            onTap: () => widget.onSelected(option.category),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (compact) ...[
          TextButton(
            onPressed: () => setState(() => _showMore = !_showMore),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(48, 48),
              textStyle: AppTextStyles.labelMedium,
            ),
            child: Text(
              _showMore
                  ? RiskReportStrings.hideOtherReasons
                  : RiskReportStrings.otherReasons,
            ),
          ),
          for (final option in secondary)
            if (_showMore || selected == option.category) ...[
              _ReasonTile(
                option: option,
                selected: selected == option.category,
                onTap: () => widget.onSelected(option.category),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        RiskReportStrings.selectedReason,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (selected) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    option.description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
