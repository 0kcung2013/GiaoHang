import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

class SubmitOrderButton extends StatelessWidget {
  const SubmitOrderButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
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
            boxShadow: AppShadow.accentGlow,
          ),
          child: Material(
            color: AppColors.accent,
            borderRadius: AppRadius.full,
            child: InkWell(
              onTap: onPressed,
              borderRadius: AppRadius.full,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.textOnAccent,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
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
