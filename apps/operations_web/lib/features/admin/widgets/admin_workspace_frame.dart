import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../../core/widgets/admin_workspace_scope.dart';
import '../../support/widgets/support_workspace_theme.dart';
import '../constants/admin_strings.dart';
import '../models/admin_section.dart';
import 'admin_navigation.dart';

class AdminWorkspaceFrame extends StatelessWidget {
  const AdminWorkspaceFrame({
    super.key,
    required this.section,
    required this.onSelect,
    required this.onSearch,
    required this.child,
  });
  final AdminSection section;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onSearch;
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: supportWorkspaceTheme(context).copyWith(
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1100;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Scaffold(
          backgroundColor: AppColors.bgLight,
          drawer: desktop
              ? null
              : Drawer(
                  width: 288,
                  child: AdminNavigation(
                    selected: section,
                    onSelect: (s) {
                      Navigator.pop(context);
                      onSelect(s);
                    },
                  ),
                ),
          body: Row(
            children: [
              if (desktop)
                AdminNavigation(selected: section, onSelect: onSelect),
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Builder(
                        builder: (scaffoldContext) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: constraints.maxWidth < 600
                                ? AppSpacing.md
                                : AppSpacing.xl2,
                            vertical: AppSpacing.md,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.bgCard,
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (!desktop)
                                IconButton(
                                  tooltip: AdminStrings.menu,
                                  onPressed: () =>
                                      Scaffold.of(scaffoldContext).openDrawer(),
                                  icon: const Icon(Icons.menu_rounded),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (desktop)
                                      Text(
                                        AdminStrings.workspace,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    Text(
                                      section.label,
                                      style: AppTextStyles.headingSmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              if (constraints.maxWidth > 800 && !largeText)
                                OutlinedButton.icon(
                                  onPressed: onSearch,
                                  icon: const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    AdminStrings.search,
                                    style: AppTextStyles.bodySmall,
                                  ),
                                )
                              else
                                IconButton(
                                  tooltip: AdminStrings.search,
                                  onPressed: onSearch,
                                  icon: const Icon(Icons.search_rounded),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: AdminWorkspaceScope(child: child)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
