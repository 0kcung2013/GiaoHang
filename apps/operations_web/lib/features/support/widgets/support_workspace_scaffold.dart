import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/support_ticket_strings.dart';
import 'support_workspace_theme.dart';
import '../notifications/support_request_bell.dart';
import '../../../core/widgets/admin_workspace_scope.dart';

enum SupportWorkspaceSection {
  risks,
  orders,
  tickets,
  monitoring,
  transactions,
  accounts,
}

class SupportWorkspaceScaffold extends StatelessWidget {
  const SupportWorkspaceScaffold({
    required this.activeSection,
    required this.body,
    super.key,
  });
  final SupportWorkspaceSection activeSection;
  final Widget body;

  @override
  Widget build(BuildContext context) => Theme(
    data: supportWorkspaceTheme(context),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (AdminWorkspaceScope.contains(context)) return body;
        final desktop = constraints.maxWidth >= 960;
        return Scaffold(
          backgroundColor: AppColors.bgLight,
          appBar: desktop
              ? null
              : AppBar(
                  toolbarHeight: 64,
                  titleSpacing: AppSpacing.screenH,
                  title: const _WorkspaceBrand(),
                  backgroundColor: AppColors.bgCard,
                  surfaceTintColor: AppColors.bgCard,
                  scrolledUnderElevation: 0,
                  shape: const Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                  actions: [
                    const SupportRequestBell(),
                    IconButton(
                      tooltip: SupportTicketStrings.signOut,
                      onPressed: () => _signOut(context),
                      icon: const Icon(Icons.logout_rounded),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),
          body: desktop
              ? Row(
                  children: [
                    _DesktopNavigation(activeSection: activeSection),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: desktop
              ? null
              : SafeArea(
                  top: false,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.bgCard,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final section in const [
                              SupportWorkspaceSection.risks,
                              SupportWorkspaceSection.tickets,
                              SupportWorkspaceSection.monitoring,
                              SupportWorkspaceSection.orders,
                              SupportWorkspaceSection.transactions,
                              SupportWorkspaceSection.accounts,
                            ])
                              SizedBox(
                                width:
                                    112 *
                                    MediaQuery.textScalerOf(
                                      context,
                                    ).scale(1).clamp(1, 1.6),
                                child: _WorkspaceDestination(
                                  section: section,
                                  selected: activeSection == section,
                                  compact: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    ),
  );
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.activeSection});
  final SupportWorkspaceSection activeSection;

  @override
  Widget build(BuildContext context) => Container(
    width: 224,
    decoration: const BoxDecoration(
      color: AppColors.bgCard,
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.xl2),
              child: Row(
                children: [
                  Expanded(child: _WorkspaceBrand()),
                  SupportRequestBell(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final section in const [
                      SupportWorkspaceSection.risks,
                      SupportWorkspaceSection.tickets,
                      SupportWorkspaceSection.monitoring,
                      SupportWorkspaceSection.orders,
                      SupportWorkspaceSection.transactions,
                      SupportWorkspaceSection.accounts,
                    ]) ...[
                      _WorkspaceDestination(
                        section: section,
                        selected: activeSection == section,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _signOut(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size(48, 48),
                alignment: Alignment.centerLeft,
                textStyle: AppTextStyles.labelMedium,
              ),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text(SupportTicketStrings.signOut),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorkspaceBrand extends StatelessWidget {
  const _WorkspaceBrand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: AppRadius.md,
        ),
        child: const Icon(Icons.support_agent_rounded, color: AppColors.accent),
      ),
      const SizedBox(width: AppSpacing.md),
      Flexible(child: Text('CSKH', style: AppTextStyles.headingSmall)),
    ],
  );
}

class _WorkspaceDestination extends StatelessWidget {
  const _WorkspaceDestination({
    required this.section,
    required this.selected,
    this.compact = false,
  });
  final SupportWorkspaceSection section;
  final bool selected;
  final bool compact;

  String get label => switch (section) {
    SupportWorkspaceSection.risks => SupportTicketStrings.riskQueue,
    SupportWorkspaceSection.orders => SupportTicketStrings.ordersQueue,
    SupportWorkspaceSection.tickets => SupportTicketStrings.ticketQueue,
    SupportWorkspaceSection.monitoring => SupportTicketStrings.monitoring,
    SupportWorkspaceSection.accounts => SupportTicketStrings.accounts,
    SupportWorkspaceSection.transactions => SupportTicketStrings.transactions,
  };
  IconData get icon => switch (section) {
    SupportWorkspaceSection.risks => Icons.shield_outlined,
    SupportWorkspaceSection.orders => Icons.inventory_2_outlined,
    SupportWorkspaceSection.tickets => Icons.forum_outlined,
    SupportWorkspaceSection.monitoring => Icons.radar_rounded,
    SupportWorkspaceSection.accounts => Icons.people_alt_outlined,
    SupportWorkspaceSection.transactions =>
      Icons.account_balance_wallet_outlined,
  };
  String get route => switch (section) {
    SupportWorkspaceSection.risks => '/support-risk',
    SupportWorkspaceSection.orders => '/support-orders',
    SupportWorkspaceSection.tickets => '/support-home',
    SupportWorkspaceSection.monitoring => '/support-monitoring',
    SupportWorkspaceSection.accounts => '/support-accounts',
    SupportWorkspaceSection.transactions => '/support-transactions',
  };

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final symbol = Icon(
      icon,
      size: 22,
      color: selected ? AppColors.accent : color,
    );
    final text = Text(
      label,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: AppTextStyles.labelMedium.copyWith(color: color),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.bgLight : Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: () => context.go(route),
          hoverColor: AppColors.bgLight,
          focusColor: AppColors.accentLight,
          borderRadius: AppRadius.md,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.xs : AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      symbol,
                      const SizedBox(height: AppSpacing.xs),
                      text,
                    ],
                  )
                : Row(
                    children: [
                      symbol,
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: text),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

Future<void> _signOut(BuildContext context) async {
  await Supabase.instance.client.auth.signOut();
  if (context.mounted) context.go('/login');
}
