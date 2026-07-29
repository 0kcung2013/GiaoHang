import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/utils/order_cargo_utils.dart';

class CargoCategorySelector extends StatelessWidget {
  const CargoCategorySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: cargoCategories.map((category) {
        final selected = value == category;
        return Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? AppColors.accentLight : const Color(0xFFF8F9FB),
            borderRadius: AppRadius.md,
            child: InkWell(
              onTap: () => onChanged(category),
              borderRadius: AppRadius.md,
              child: AnimatedContainer(
                duration: AppDuration.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.md,
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: AppDuration.fast,
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : AppColors.bgCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: AppColors.textOnAccent,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      cargoCategoryLabel(category),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
