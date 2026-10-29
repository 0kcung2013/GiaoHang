import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../support/screens/support_home_screen.dart';
import '../../support_monitoring/screens/support_monitoring_screen.dart';
import '../../support_transactions/screens/support_transactions_screen.dart';
import '../data/admin_repository.dart';
import '../data/admin_order_repository.dart';
import '../dialogs/admin_command_dialog.dart';
import '../models/admin_section.dart';
import '../widgets/admin_workspace_frame.dart';
import '../../account_controls/screens/account_controls_screen.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'drivers/admin_drivers_screen.dart';
import 'orders/admin_orders_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'configuration/business_configuration_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({
    super.key,
    this.section = AdminSection.overview,
    this.query = '',
    this.view = '',
    this.riskReportId,
    this.ticketId,
    this.detail,
    this.repository,
    this.orderRepository,
    this.sectionBuilder,
    this.onNavigate,
  });
  final AdminSection section;
  final String query;
  final String view;
  final String? riskReportId, ticketId;
  final Widget? detail;
  final AdminRepository? repository;
  final AdminOrderRepository? orderRepository;
  final Widget Function(AdminSection)? sectionBuilder;
  final ValueChanged<AdminSection>? onNavigate;
  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  final _visited = <AdminSection, Widget>{};
  final _locations = <AdminSection, ({String query, String view})>{};
  bool _searchOpen = false;
  final _configurationKey = GlobalKey<BusinessConfigurationScreenState>();
  void _navigate(AdminSection section, {String? query, String? view}) async {
    if (widget.section == AdminSection.configuration &&
        section != widget.section) {
      if (!(await _configurationKey.currentState?.confirmLeave() ?? true) ||
          !mounted) {
        return;
      }
    }
    if (widget.onNavigate != null) {
      widget.onNavigate!(section);
      return;
    }
    final saved = _locations[section];
    final nextQuery = query ?? saved?.query ?? '';
    final nextView = view ?? saved?.view ?? '';
    context.go(
      Uri(
        path: '/admin-home',
        queryParameters: {
          'section': section.slug,
          if (nextQuery.isNotEmpty) 'q': nextQuery,
          if (nextView.isNotEmpty) 'view': nextView,
        },
      ).toString(),
    );
  }

  Future<void> _search() async {
    if (_searchOpen) return;
    _searchOpen = true;
    final command = await showAdminCommandDialog(context);
    _searchOpen = false;
    if (command != null && mounted) {
      _navigate(command.section, query: command.query);
    }
  }

  Widget _screen(AdminSection section) =>
      widget.sectionBuilder?.call(section) ??
      switch (section) {
        AdminSection.overview => AdminDashboardScreen(
          repository: widget.repository,
          onNavigate: _navigate,
          onProfileChanges: () =>
              _navigate(AdminSection.drivers, view: 'changes'),
          onDisabledAccounts: () =>
              _navigate(AdminSection.accounts, view: 'disabled'),
        ),
        AdminSection.orders => AdminOrdersScreen(
          repository: widget.orderRepository,
          initialQuery: widget.query,
        ),
        AdminSection.drivers => AdminDriversScreen(
          initialTab: widget.view == 'changes' ? 3 : 0,
        ),
        AdminSection.monitoring => const SupportHomeScreen(
          isAdmin: true,
          monitoring: true,
        ),
        AdminSection.journeys => SupportMonitoringScreen(
          onCases: () => _navigate(AdminSection.monitoring),
        ),
        AdminSection.transactions => const SupportTransactionsScreen(),
        AdminSection.accounts => AccountControlsScreen(
          isAdmin: true,
          initialSearch: widget.query,
          disabledOnly: widget.view == 'disabled',
          riskReportId: widget.riskReportId,
          ticketId: widget.ticketId,
        ),
        AdminSection.settings => AdminSettingsScreen(onNavigate: _navigate),
        AdminSection.configuration => BusinessConfigurationScreen(
          key: _configurationKey,
        ),
      };
  @override
  Widget build(BuildContext context) {
    if (widget.detail == null) {
      _locations[widget.section] = (query: widget.query, view: widget.view);
    }
    // Khởi tạo khi ghé module lần đầu; giữ bộ lọc/hội thoại khi đổi module.
    if (widget.detail == null) {
      _visited[widget.section] = KeyedSubtree(
        key: ValueKey(widget.section),
        child: _screen(widget.section),
      );
    }
    final sections = _visited.keys.toList();
    final content =
        widget.detail ??
        IndexedStack(
          index: sections.indexOf(widget.section),
          children: sections.map((s) => _visited[s]!).toList(),
        );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _search,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _search,
      },
      child: Focus(
        autofocus: true,
        child: AdminWorkspaceFrame(
          section: widget.section,
          onSelect: _navigate,
          onSearch: _search,
          child: content,
        ),
      ),
    );
  }
}
