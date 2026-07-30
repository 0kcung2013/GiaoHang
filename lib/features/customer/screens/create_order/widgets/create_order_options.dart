import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/utils/order_cargo_utils.dart';

const cargoCategoryOptionKey = Key('cargo-category-option');

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final spacing = AppSpacing.sm * (columns - 1);
        final itemWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final category in cargoCategories)
              SizedBox(
                width: itemWidth,
                child: _CategoryOption(
                  category: category,
                  selected: value == category,
                  onTap: () => onChanged(category),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: cargoCategoryLabel(category),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: AnimatedContainer(
            key: cargoCategoryOptionKey,
            duration: AppDuration.fast,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentLight : AppColors.bgLight,
              borderRadius: AppRadius.lg,
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected ? AppShadow.subtle : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.bgCard,
                    borderRadius: AppRadius.md,
                    border: selected
                        ? null
                        : Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    _categoryIcon(category),
                    size: 18,
                    color: selected
                        ? AppColors.textOnAccent
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    cargoCategoryLabel(category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.accent,
                    size: 17,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'food' => Icons.restaurant_rounded,
    'document' => Icons.description_rounded,
    'parcel' => Icons.inventory_2_rounded,
    'fragile' => Icons.wine_bar_rounded,
    'grocery' => Icons.shopping_bag_rounded,
    _ => Icons.category_rounded,
  };
}
