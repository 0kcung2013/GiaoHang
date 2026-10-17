import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../utils/driver_order_filter.dart';

class DriverOrdersFilterBar extends StatelessWidget {
  final DriverOrderFilter selectedFilter;
  final ValueChanged<DriverOrderFilter> onChanged;
  final Map<DriverOrderFilter, int> counts;
  final List<DriverOrderFilter> filters;

  const DriverOrdersFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
    required this.counts,
    this.filters = DriverOrderFilter.values,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          for (var index = 0; index < filters.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FilterButton(
                filter: filters[index],
                count: counts[filters[index]] ?? 0,
                isSelected: filters[index] == selectedFilter,
                onTap: () => onChanged(filters[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final DriverOrderFilter filter;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.filter,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? AppColors.textOnAccent
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${filter.label}, $count đơn',
      child: Material(
        color: isSelected ? AppColors.accent : AppColors.bgLight,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : AppColors.border.withValues(alpha: 0.7),
              ),
              boxShadow: isSelected ? AppShadow.accentGlow : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(filter.icon, size: 17, color: foreground),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.textOnAccent.withValues(alpha: 0.2)
                            : AppColors.bgCard,
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
                const SizedBox(height: AppSpacing.xs),
                Text(
                  filter.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
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
