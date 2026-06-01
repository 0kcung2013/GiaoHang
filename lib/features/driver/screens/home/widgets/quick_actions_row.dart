import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import 'driver_state_widgets.dart';

/// Row of quick-action icon buttons (Refresh, Navigation, History).
class QuickActionsRow extends StatelessWidget {
  final VoidCallback onRefresh;

  const QuickActionsRow({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return DriverSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.refresh_rounded,
                label: 'Làm mới',
                onTap: onRefresh,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: _QuickActionButton(
                icon: Icons.navigation_rounded,
                label: 'Điều hướng',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: _QuickActionButton(
                icon: Icons.history_rounded,
                label: 'Lịch sử',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.info, size: 22),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
