import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';

class DriverOrdersScreen extends StatelessWidget {
  const DriverOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DriverPlaceholderScreen(
      icon: Icons.list_alt_rounded,
      title: 'Don hang',
      message: 'Danh sach don hang cua tai xe se duoc bo sung o day.',
    );
  }
}

class _DriverPlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DriverPlaceholderScreen({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
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
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.accent, size: 28),
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
