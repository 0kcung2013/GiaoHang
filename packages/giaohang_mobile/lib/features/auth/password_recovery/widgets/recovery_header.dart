import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../password_recovery_controller.dart';
import '../password_recovery_strings.dart';

class RecoveryHeader extends StatelessWidget {
  const RecoveryHeader({super.key, required this.step, required this.email});
  final PasswordRecoveryStep step;
  final String email;

  @override
  Widget build(BuildContext context) {
    final success = step == PasswordRecoveryStep.success;
    final (icon, title, hint) = switch (step) {
      PasswordRecoveryStep.email => (
        Icons.lock_reset_rounded,
        PasswordRecoveryStrings.title,
        PasswordRecoveryStrings.emailHint,
      ),
      PasswordRecoveryStep.code => (
        Icons.mark_email_read_rounded,
        PasswordRecoveryStrings.codeTitle,
        PasswordRecoveryStrings.codeHint,
      ),
      PasswordRecoveryStep.password => (
        Icons.password_rounded,
        PasswordRecoveryStrings.passwordTitle,
        PasswordRecoveryStrings.passwordHint,
      ),
      PasswordRecoveryStep.success => (
        Icons.check_circle_outline_rounded,
        PasswordRecoveryStrings.successTitle,
        PasswordRecoveryStrings.successHint,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!success) ...[
          Semantics(
            label: PasswordRecoveryStrings.progress(step.index + 1),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: AppSpacing.xs,
                            decoration: BoxDecoration(
                              color: i <= step.index
                                  ? AppColors.accent
                                  : AppColors.border,
                              borderRadius: AppRadius.full,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            [
                              PasswordRecoveryStrings.emailStep,
                              PasswordRecoveryStrings.codeStep,
                              PasswordRecoveryStrings.passwordStep,
                            ][i],
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: i == step.index
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl4),
        ],
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: success
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.accentLight,
            borderRadius: AppRadius.xl2,
          ),
          child: Icon(
            icon,
            size: 36,
            color: success ? AppColors.success : AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        Semantics(
          header: true,
          liveRegion: success,
          child: Text(
            title,
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          hint,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (step == PasswordRecoveryStep.code ||
            step == PasswordRecoveryStep.password) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                step == PasswordRecoveryStep.password
                    ? Icons.verified_user_outlined
                    : Icons.alternate_email_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  email,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (step == PasswordRecoveryStep.password) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              PasswordRecoveryStrings.verified,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
