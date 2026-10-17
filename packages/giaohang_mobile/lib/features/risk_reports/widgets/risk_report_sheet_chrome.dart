import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../utils/risk_report_strings.dart';

class RiskReportSheetHeader extends StatelessWidget {
  const RiskReportSheetHeader({
    required this.step,
    required this.onClose,
    this.title = RiskReportStrings.reportTitle,
    this.showSteps = true,
    super.key,
  });

  final int step;
  final VoidCallback? onClose;
  final String title;
  final bool showSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.full,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: showSteps
                      ? AppTextStyles.headingLarge
                      : AppTextStyles.headingMedium,
                ),
              ),
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(48, 48),
                  textStyle: AppTextStyles.labelMedium,
                ),
                child: const Text(RiskReportStrings.closeAction),
              ),
            ],
          ),
          if (showSteps)
            Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      right: index == 2 ? 0 : AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: index <= step
                          ? AppColors.accent
                          : AppColors.border,
                      borderRadius: AppRadius.full,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RiskReportSheetFooter extends StatelessWidget {
  const RiskReportSheetFooter({
    required this.step,
    required this.submitting,
    required this.submissionLabel,
    required this.errorMessage,
    required this.onBack,
    required this.onPrimary,
    this.submitLabel = RiskReportStrings.sendReport,
    this.singlePage = false,
    super.key,
  });

  final int step;
  final bool submitting;
  final String submissionLabel;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onPrimary;
  final String submitLabel;
  final bool singlePage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (submitting) ...[
                Semantics(
                  liveRegion: true,
                  label: submissionLabel,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      submissionLabel,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const ClipRRect(
                  borderRadius: AppRadius.full,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: AppColors.accent,
                    backgroundColor: AppColors.accentLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (errorMessage != null) ...[
                Text(
                  errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  if (!singlePage && step > 0) ...[
                    Expanded(
                      child: _SheetButton(
                        label: 'Quay lại',
                        onTap: submitting ? null : onBack,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: step > 0 ? 2 : 1,
                    child: _SheetButton(
                      label: singlePage || step == 2 ? submitLabel : 'Tiếp tục',
                      onTap: submitting ? null : onPrimary,
                      loading: submitting,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.secondary = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool secondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: secondary ? AppColors.bgCard : AppColors.accent,
        foregroundColor: secondary
            ? AppColors.textPrimary
            : AppColors.textOnAccent,
        side: secondary ? const BorderSide(color: AppColors.border) : null,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        textStyle: AppTextStyles.labelLarge,
      ),
      child: Text(
        loading ? 'Vui lòng chờ…' : label,
        textAlign: TextAlign.center,
      ),
    );
  }
}
