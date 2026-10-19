import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';
import '../constants/support_monitoring_strings.dart';
import 'support_case_list_item.dart';

class SupportTicketCard extends StatelessWidget {
  const SupportTicketCard({
    required this.ticket,
    required this.onTap,
    super.key,
  });
  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SupportCaseListItem(
    title: ticket.isAutomaticMonitoringNotice
        ? SupportMonitoringStrings.reclaimed
        : ticket.subject,
    identity: [
      if (ticket.orderId != null)
        ticket.trackingCode ?? SupportTicketUi.shortId(ticket.orderId!),
      '${SupportTicketUi.requesterRoleLabel(ticket.requesterRole)}: ${ticket.requesterName ?? SupportTicketUi.shortId(ticket.requesterId)}',
    ].join(' · '),
    preview: ticket.isAutomaticMonitoringNotice
        ? SupportMonitoringStrings.automaticSummary
        : CaseMessageContent.decode(
            ticket.lastMessageBody ?? ticket.message,
          ).text,
    assignment: ticket.isAutomaticMonitoringNotice
        ? SupportMonitoringStrings.noAcceptance
        : ticket.assignedTo == null
        ? 'Chưa tiếp nhận'
        : (ticket.assignedToName ?? 'Đã có người phụ trách'),
    time: SupportTicketUi.dateTimeLabel(ticket.updatedAt),
    status: ticket.isAutomaticMonitoringNotice
        ? SupportMonitoringStrings.automaticStatus
        : SupportTicketUi.statusLabel(ticket.status),
    statusColor: ticket.isAutomaticMonitoringNotice
        ? AppColors.textSecondary
        : SupportTicketUi.statusColor(ticket.status),
    icon: ticket.isAutomaticMonitoringNotice
        ? Icons.history_rounded
        : ticket.isMonitoring
        ? Icons.gps_off_rounded
        : Icons.forum_outlined,
    onTap: onTap,
    alerts: [
      if (ticket.needsSupportAttention &&
          ticket.priority == SupportTicketPriority.high)
        Text(
          'Ưu tiên cao',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
        ),
      if (ticket.needsReply)
        Text(
          'Cần phản hồi',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent),
        ),
    ],
  );
}
