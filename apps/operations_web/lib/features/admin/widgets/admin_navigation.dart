import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/admin_strings.dart';
import '../models/admin_section.dart';
import 'admin_navigation_item.dart';

class AdminNavigation extends StatefulWidget {
  const AdminNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;
  @override
  State<AdminNavigation> createState() => _AdminNavigationState();
}

class _AdminNavigationState extends State<AdminNavigation> {
  late bool _lookupsExpanded = widget.selected.isLookup;

  @override
  void didUpdateWidget(covariant AdminNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A direct link or command search must reveal its selected destination.
    if (widget.selected != oldWidget.selected && widget.selected.isLookup) {
      _lookupsExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 248,
    child: ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl2),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: AppRadius.md,
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.textOnAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AdminStrings.brand,
                          style: AppTextStyles.headingMedium.copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                        Text(
                          AdminStrings.administrator,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textOnDark.withValues(alpha: .7),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  for (final section in AdminSection.primary) ...[
                    if (section == AdminSection.overview ||
                        section.group !=
                            AdminSection
                                .primary[AdminSection.primary.indexOf(section) -
                                    1]
                                .group)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          section.group.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            letterSpacing: 1.3,
                            color: AppColors.textOnDark.withValues(alpha: .55),
                          ),
                        ),
                      ),
                    AdminNavigationItem(
                      section: section,
                      selected: widget.selected == section,
                      onSelect: widget.onSelect,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    expanded: _lookupsExpanded,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: AppRadius.md,
                      child: InkWell(
                        key: const ValueKey('admin-lookup-toggle'),
                        borderRadius: AppRadius.md,
                        onTap: () => setState(
                          () => _lookupsExpanded = !_lookupsExpanded,
                        ),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AdminStrings.operationsLookup,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textOnDark,
                                  ),
                                ),
                              ),
                              Icon(
                                _lookupsExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: AppColors.textOnDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_lookupsExpanded)
                    for (final section in AdminSection.lookups)
                      AdminNavigationItem(
                        section: section,
                        selected: widget.selected == section,
                        onSelect: widget.onSelect,
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Material(
                color: AppColors.textOnDark.withValues(alpha: .06),
                borderRadius: AppRadius.md,
                child: InkWell(
                  key: const ValueKey('admin-nav-settings'),
                  onTap: () => widget.onSelect(AdminSection.settings),
                  borderRadius: AppRadius.md,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AppColors.textOnDark,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            AdminStrings.roleLabel('admin'),
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textOnDark,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.textOnDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
