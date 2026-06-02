import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

class SubmitOrderButton extends StatelessWidget {
  const SubmitOrderButton({
    super.key,
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        boxShadow: AppShadow.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: AppRadius.full,
            boxShadow: isSubmitting ? null : AppShadow.accentGlow,
          ),
          child: Material(
            color: isSubmitting
                ? AppColors.accent.withValues(alpha: 0.62)
                : AppColors.accent,
            borderRadius: AppRadius.full,
            child: InkWell(
              onTap: isSubmitting ? null : onPressed,
              borderRadius: AppRadius.full,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSubmitting
                          ? Icons.hourglass_empty_rounded
                          : Icons.check_circle_rounded,
                      color: AppColors.textOnAccent,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isSubmitting ? 'Đang tạo đơn...' : 'Tạo đơn hàng',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textOnAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
