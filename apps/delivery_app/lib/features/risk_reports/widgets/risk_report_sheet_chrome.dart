import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class RiskReportSheetHeader extends StatelessWidget {
  const RiskReportSheetHeader({
    required this.step,
    required this.onClose,
    super.key,
  });

  final int step;
  final VoidCallback onClose;

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
                child: Text('Báo cáo sự cố', style: AppTextStyles.headingLarge),
              ),
              Semantics(
                button: true,
                label: 'Đóng',
                child: InkWell(
                  onTap: onClose,
                  borderRadius: AppRadius.full,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                    color: index <= step ? AppColors.accent : AppColors.border,
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
    required this.errorMessage,
    required this.onBack,
    required this.onPrimary,
    super.key,
  });

  final int step;
  final bool submitting;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onPrimary;

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
                  if (step > 0) ...[
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
                      label: step == 2 ? 'Gửi cho CSKH' : 'Tiếp tục',
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
    return Material(
      color: secondary ? AppColors.bgCard : AppColors.accent,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: secondary ? Border.all(color: AppColors.border) : null,
          ),
          child: Text(
            loading ? 'Đang gửi…' : label,
            style: AppTextStyles.labelLarge.copyWith(
              color: secondary ? AppColors.textPrimary : AppColors.textOnAccent,
            ),
          ),
        ),
      ),
    );
  }
}
