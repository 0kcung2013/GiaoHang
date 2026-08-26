import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class RiskReportEntryAction extends StatelessWidget {
  const RiskReportEntryAction({
    required this.onPressed,
    this.label = 'Báo cáo sự cố',
    this.dark = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? AppColors.textOnDark : AppColors.textSecondary;
    final background = dark ? AppColors.bgDarkCard : AppColors.bgCard;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Material(
        color: background,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.md,
          child: Container(
            key: const ValueKey('risk-report-entry-surface'),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadius.md,
              border: Border.all(
                color: dark ? AppColors.warning : AppColors.border,
              ),
              boxShadow: dark ? AppShadow.elevated : AppShadow.subtle,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: foreground,
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
}
