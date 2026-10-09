import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class DriverCancellationReasonCard extends StatelessWidget {
  const DriverCancellationReasonCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.available,
    required this.onPressed,
    this.status,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool available;
  final VoidCallback? onPressed;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final foreground = available
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      enabled: available && onPressed != null,
      child: OutlinedButton(
        onPressed: available ? onPressed : null,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(AppSpacing.lg),
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          backgroundColor: selected
              ? AppColors.accentLight
              : available
              ? AppColors.bgCard
              : AppColors.bgLight,
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: available ? 1 : 0.45,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.bgLight,
                      borderRadius: AppRadius.md,
                    ),
                    child: Icon(
                      icon,
                      color: selected ? AppColors.accent : foreground,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  !available
                      ? Icons.lock_outline_rounded
                      : selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: AppSpacing.md),
              status!,
            ],
          ],
        ),
      ),
    );
  }
}
