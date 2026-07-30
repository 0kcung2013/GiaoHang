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
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.72)),
        ),
        boxShadow: AppShadow.subtle,
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          label: label,
          child: SizedBox(
            height: 60,
            child: Material(
              color: AppColors.accent,
              borderRadius: AppRadius.full,
              shadowColor: AppColors.accent,
              elevation: 3,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                borderRadius: AppRadius.full,
                splashColor: AppColors.textPrimary.withValues(alpha: 0.1),
                child: Center(
                  child: Row(
                    children: [
                      const SizedBox(width: AppSpacing.lg),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.textOnAccent.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.textOnAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textOnAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Kiểm tra thông tin trước khi đặt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textOnAccent.withValues(
                                  alpha: 0.76,
                                ),
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.textOnAccent,
                        size: 21,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
