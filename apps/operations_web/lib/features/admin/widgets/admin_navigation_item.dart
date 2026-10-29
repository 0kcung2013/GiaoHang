import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/admin_section.dart';

class AdminNavigationItem extends StatelessWidget {
  const AdminNavigationItem({
    super.key,
    required this.section,
    required this.selected,
    required this.onSelect,
  });
  final AdminSection section;
  final bool selected;
  final ValueChanged<AdminSection> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Semantics(
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.textOnDark.withValues(alpha: .12)
            : Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
          key: ValueKey('admin-nav-${section.slug}'),
          borderRadius: AppRadius.md,
          onTap: () => onSelect(section),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 20,
                  color: selected
                      ? AppColors.accent
                      : AppColors.textOnDark.withValues(alpha: .7),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    section.label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.circle, size: 5, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
