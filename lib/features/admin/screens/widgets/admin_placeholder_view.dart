import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';

class AdminPlaceholderView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accentColor;

  const AdminPlaceholderView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl2),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: AppRadius.lg,
                  ),
                  child: Icon(icon, color: accentColor, size: 30),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
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
