import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class CustomerTypeChoice extends StatelessWidget {
  const CustomerTypeChoice({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title, description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.accentLight : AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
        side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.accent : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(description, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
