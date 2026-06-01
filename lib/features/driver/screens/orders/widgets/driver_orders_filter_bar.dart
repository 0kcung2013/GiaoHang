import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../utils/driver_order_filter.dart';

class DriverOrdersFilterBar extends StatelessWidget {
  final DriverOrderFilter selectedFilter;
  final ValueChanged<DriverOrderFilter> onChanged;
  final Map<DriverOrderFilter, int> counts;

  const DriverOrdersFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Row(
        children: DriverOrderFilter.values.map((filter) {
          final isSelected = filter == selectedFilter;
          return Expanded(
            child: _FilterButton(
              label: filter.label,
              count: counts[filter] ?? 0,
              isSelected: isSelected,
              onTap: () => onChanged(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? AppColors.textOnAccent
        : AppColors.textSecondary;

    return Material(
      color: isSelected ? AppColors.info : Colors.transparent,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textOnAccent.withValues(alpha: 0.18)
                        : AppColors.bgLight,
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    count.toString(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
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
