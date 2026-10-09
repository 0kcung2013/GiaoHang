import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/support_ticket.dart';
import '../models/support_ticket_policy.dart';

class SupportTicketActions extends StatelessWidget {
  const SupportTicketActions({
    required this.ticket,
    required this.assignedToMe,
    required this.isAdmin,
    required this.busy,
    required this.completionBlocked,
    required this.onShowContext,
    required this.onAccept,
    required this.onTakeOver,
    required this.onTransition,
    required this.onConvert,
    super.key,
  });

  final SupportTicket ticket;
  final bool assignedToMe;
  final bool isAdmin;
  final bool busy;
  final bool completionBlocked;
  final VoidCallback onShowContext;
  final VoidCallback onAccept;
  final VoidCallback onTakeOver;
  final ValueChanged<SupportTicketStatus> onTransition;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    final transitions = SupportTicketPolicy.allowedTransitions(ticket.status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.end,
        children: [
          if (assignedToMe && !ticket.status.isClosed && completionBlocked)
            TextButton.icon(
              onPressed: onShowContext,
              icon: const Icon(Icons.pending_actions_rounded),
              label: const Text('Còn việc cần xử lý · Xem thông tin'),
            ),
          if (assignedToMe &&
              !ticket.status.isClosed &&
              ticket.riskReportId == null)
            TextButton.icon(
              onPressed: busy ? null : onConvert,
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Chuyển báo cáo sự cố'),
            ),
          if (ticket.assignedTo == null)
            FilledButton.icon(
              key: const Key('accept-support-ticket'),
              onPressed: busy ? null : onAccept,
              icon: const Icon(Icons.person_add_alt_rounded, size: 18),
              label: const Text('Nhận xử lý'),
            )
          else if (!assignedToMe && isAdmin)
            OutlinedButton.icon(
              key: const Key('takeover-support-ticket'),
              onPressed: busy ? null : onTakeOver,
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: const Text('Tiếp quản'),
            )
          else if (!assignedToMe)
            Text(
              'Đã có người phụ trách',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textMuted,
              ),
            )
          else if (transitions.isNotEmpty)
            FilledButton.icon(
              key: const Key('finish-support-ticket'),
              onPressed: busy || (!ticket.status.isClosed && completionBlocked)
                  ? null
                  : () => onTransition(
                      ticket.status.isClosed
                          ? SupportTicketStatus.inProgress
                          : SupportTicketStatus.resolved,
                    ),
              icon: Icon(
                ticket.status.isClosed
                    ? Icons.replay_rounded
                    : Icons.check_circle_outline_rounded,
              ),
              label: Text(ticket.status.isClosed ? 'Mở lại' : 'Kết thúc'),
            ),
        ],
      ),
    );
  }
}
