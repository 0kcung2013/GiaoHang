import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../controllers/business_settings_controller.dart';
import '../models/settings_section.dart';
import '../settings_strings.dart';

class SettingsSectionNavigation extends StatelessWidget {
  const SettingsSectionNavigation({
    super.key,
    required this.selected,
    required this.controller,
    required this.onSelected,
    this.compact = false,
  });

  final SettingsSection selected;
  final BusinessSettingsController controller;
  final ValueChanged<SettingsSection> onSelected;
  final bool compact;

  int _changes(SettingsSection section) => section.group == null
      ? controller.changedFields.length
      : controller.changesIn(section.group!);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: SettingsStrings.sections,
          labelStyle: AppTextStyles.bodySmall,
          filled: true,
          fillColor: AppColors.bgCard,
          border: const OutlineInputBorder(borderRadius: AppRadius.md),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<SettingsSection>(
            key: const ValueKey('settings-section-picker'),
            value: selected,
            isExpanded: true,
            itemHeight: null,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            dropdownColor: AppColors.bgCard,
            borderRadius: AppRadius.md,
            onChanged: controller.saving
                ? null
                : (value) {
                    if (value != null) onSelected(value);
                  },
            selectedItemBuilder: (_) => [
              for (final section in SettingsSection.values)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      section.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
            items: [
              for (final section in SettingsSection.values)
                DropdownMenuItem(
                  value: section,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Icon(section.icon, size: 20, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(section.label)),
                        if (_changes(section) > 0) ...[
                          const SizedBox(width: AppSpacing.sm),
                          _Count(_changes(section)),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Text(
            SettingsStrings.sections,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        for (final section in SettingsSection.values) ...[
          if (section == SettingsSection.review)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(color: AppColors.border),
            ),
          _SectionTile(
            section: section,
            selected: selected == section,
            count: _changes(section),
            enabled: !controller.saving,
            onTap: () => onSelected(section),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.selected,
    required this.count,
    required this.enabled,
    required this.onTap,
  });
  final SettingsSection section;
  final bool selected, enabled;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: AppRadius.md,
      child: InkWell(
        key: ValueKey('settings-section-${section.name}'),
        borderRadius: AppRadius.md,
        focusColor: AppColors.info.withValues(alpha: 0.2),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                section.icon,
                size: 20,
                color: selected
                    ? AppColors.textOnDark
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: selected
                            ? AppColors.textOnDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (section.group != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        SettingsStrings.parameters(
                          section.group!.fields.length,
                        ),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: selected
                              ? AppColors.textOnDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                _Count(count),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
    label: SettingsStrings.sectionChanges(count),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.full,
      ),
      child: Text(
        '$count',
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    ),
  );
}
