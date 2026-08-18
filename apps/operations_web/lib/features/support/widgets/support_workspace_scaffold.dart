import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/support_ticket_strings.dart';

enum SupportWorkspaceSection { risks, tickets }

class SupportWorkspaceScaffold extends StatelessWidget {
  const SupportWorkspaceScaffold({
    required this.activeSection,
    required this.body,
    super.key,
  });

  final SupportWorkspaceSection activeSection;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 960) {
          return Scaffold(
            backgroundColor: AppColors.bgLight,
            body: Row(
              children: [
                _DesktopSupportNavigation(activeSection: activeSection),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.bgLight,
          appBar: AppBar(
            toolbarHeight: 64,
            titleSpacing: AppSpacing.screenH,
            title: const _WorkspaceBrand(compact: true),
            backgroundColor: AppColors.bgCard,
            surfaceTintColor: AppColors.bgCard,
            scrolledUnderElevation: 0,
            shape: const Border(bottom: BorderSide(color: AppColors.border)),
            actions: [
              IconButton(
                tooltip: SupportTicketStrings.signOut,
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: body,
          bottomNavigationBar: _MobileSupportNavigation(
            activeSection: activeSection,
          ),
        );
      },
    );
  }
}

class _DesktopSupportNavigation extends StatelessWidget {
  const _DesktopSupportNavigation({required this.activeSection});

  final SupportWorkspaceSection activeSection;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: 256,
        color: AppColors.primary,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.xl3,
              ),
              child: _WorkspaceBrand(onDark: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'KHÔNG GIAN LÀM VIỆC',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.48),
                  letterSpacing: 0.9,
                ),
              ),
            ),
            _WorkspaceDestination(
              label: SupportTicketStrings.riskQueue,
              icon: Icons.shield_outlined,
              selectedIcon: Icons.shield_rounded,
              selected: activeSection == SupportWorkspaceSection.risks,
              onDark: true,
              onTap: () => context.go('/support-risk'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _WorkspaceDestination(
              label: SupportTicketStrings.ticketQueue,
              icon: Icons.forum_outlined,
              selectedIcon: Icons.forum_rounded,
              selected: activeSection == SupportWorkspaceSection.tickets,
              onDark: true,
              onTap: () => context.go('/support-home'),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.textOnDark.withValues(alpha: 0.06),
                borderRadius: AppRadius.md,
                border: Border.all(
                  color: AppColors.textOnDark.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: AppRadius.sm,
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      size: 20,
                      color: AppColors.textOnAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhân viên CSKH',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                        Text(
                          'Đang hoạt động',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textOnDark.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _WorkspaceDestination(
              label: SupportTicketStrings.signOut,
              icon: Icons.logout_rounded,
              selectedIcon: Icons.logout_rounded,
              selected: false,
              onDark: true,
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileSupportNavigation extends StatelessWidget {
  const _MobileSupportNavigation({required this.activeSection});

  final SupportWorkspaceSection activeSection;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: AppShadow.subtle,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: _WorkspaceDestination(
                  label: SupportTicketStrings.riskQueue,
                  icon: Icons.shield_outlined,
                  selectedIcon: Icons.shield_rounded,
                  selected: activeSection == SupportWorkspaceSection.risks,
                  centered: true,
                  onTap: () => context.go('/support-risk'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _WorkspaceDestination(
                  label: SupportTicketStrings.ticketQueue,
                  icon: Icons.forum_outlined,
                  selectedIcon: Icons.forum_rounded,
                  selected: activeSection == SupportWorkspaceSection.tickets,
                  centered: true,
                  onTap: () => context.go('/support-home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceBrand extends StatelessWidget {
  const _WorkspaceBrand({this.compact = false, this.onDark = false});

  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: onDark ? AppColors.accent : AppColors.primary,
            borderRadius: AppRadius.md,
          ),
          child: Icon(
            Icons.support_agent_rounded,
            color: onDark ? AppColors.textOnAccent : AppColors.textOnDark,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                compact ? 'CSKH' : SupportTicketStrings.workspace,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headingSmall.copyWith(
                  color: onDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
              if (!compact)
                Text(
                  'GiaoHang Operations',
                  maxLines: 1,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: onDark
                        ? AppColors.textOnDark.withValues(alpha: 0.54)
                        : AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkspaceDestination extends StatelessWidget {
  const _WorkspaceDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.centered = false,
    this.onDark = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool centered;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? (onDark
                  ? AppColors.textOnDark.withValues(alpha: 0.1)
                  : AppColors.accentLight)
            : Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: onDark
              ? AppColors.textOnDark.withValues(alpha: 0.05)
              : AppColors.bgLight,
          borderRadius: AppRadius.md,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: centered
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: selected
                      ? AppColors.accent
                      : (onDark
                            ? AppColors.textOnDark.withValues(alpha: 0.68)
                            : AppColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected
                          ? (onDark
                                ? AppColors.textOnDark
                                : AppColors.textPrimary)
                          : (onDark
                                ? AppColors.textOnDark.withValues(alpha: 0.68)
                                : AppColors.textSecondary),
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

Future<void> _signOut(BuildContext context) async {
  await Supabase.instance.client.auth.signOut();
  if (context.mounted) context.go('/login');
}
