import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';

/// Giữ hội thoại có đủ chỗ; màn hình ngắn cuộn cả hồ sơ.
class SupportTicketWorkspace extends StatefulWidget {
  const SupportTicketWorkspace({
    required this.header,
    required this.alerts,
    required this.chat,
    required this.contextPanel,
    required this.actions,
    required this.showContext,
    required this.onContextChanged,
    super.key,
  });
  final Widget header;
  final List<Widget> alerts;
  final Widget chat;
  final Widget contextPanel;
  final Widget actions;
  final bool showContext;
  final ValueChanged<bool> onContextChanged;

  @override
  State<SupportTicketWorkspace> createState() => _SupportTicketWorkspaceState();
}

class _SupportTicketWorkspaceState extends State<SupportTicketWorkspace> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant SupportTicketWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showContext && widget.showContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final short = constraints.maxHeight < 560 * scale;
      final pane = LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                Expanded(child: widget.chat),
                const VerticalDivider(width: 1, color: AppColors.border),
                SizedBox(width: 292, child: widget.contextPanel),
              ],
            );
          }
          return Column(
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _tab(
                    context,
                    SupportTicketStrings.conversation,
                    Icons.forum_outlined,
                    false,
                  ),
                  _tab(
                    context,
                    SupportTicketStrings.caseInfo,
                    Icons.inventory_2_outlined,
                    true,
                  ),
                ],
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: IndexedStack(
                  index: widget.showContext ? 1 : 0,
                  children: [widget.chat, widget.contextPanel],
                ),
              ),
            ],
          );
        },
      );
      final content = Column(
        children: [
          widget.header,
          ...widget.alerts,
          if (short)
            SizedBox(height: 420, child: pane)
          else
            Expanded(child: pane),
          widget.actions,
        ],
      );
      return short
          ? SingleChildScrollView(controller: _scrollController, child: content)
          : content;
    },
  );

  Widget _tab(
    BuildContext context,
    String label,
    IconData icon,
    bool contextSelected,
  ) => Semantics(
    selected: widget.showContext == contextSelected,
    child: TextButton.icon(
      onPressed: () {
        FocusScope.of(context).unfocus();
        widget.onContextChanged(contextSelected);
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: widget.showContext == contextSelected
            ? AppColors.accentLight
            : Colors.transparent,
        foregroundColor: widget.showContext == contextSelected
            ? AppColors.accent
            : AppColors.textSecondary,
        textStyle: AppTextStyles.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}
