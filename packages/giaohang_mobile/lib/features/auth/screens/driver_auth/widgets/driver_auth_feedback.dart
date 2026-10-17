import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class DriverAuthNotice extends StatelessWidget {
  const DriverAuthNotice({
    super.key,
    required this.message,
    this.error = false,
  });
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.error : AppColors.textSecondary;
    return Semantics(
      liveRegion: error,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: error
              ? AppColors.error.withValues(alpha: 0.06)
              : AppColors.bgLight,
          borderRadius: AppRadius.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.shield_outlined,
              size: 20,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverAuthButton extends StatelessWidget {
  const DriverAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.primary,
      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
      disabledForegroundColor: AppColors.textPrimary,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.all(AppSpacing.lg),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      textStyle: AppTextStyles.labelLarge,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
              semanticsLabel: loadingLabel ?? label,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        Flexible(
          child: Text(
            loading ? loadingLabel ?? label : label,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}
