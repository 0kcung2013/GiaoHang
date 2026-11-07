import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class DispatchSelectionField extends StatelessWidget {
  const DispatchSelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.placeholder = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool placeholder;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: onTap == null ? AppColors.textMuted : AppColors.info,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      value,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: placeholder
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontWeight: placeholder
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: onTap == null
                    ? AppColors.textMuted
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
