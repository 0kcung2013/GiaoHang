import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';
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
    title: ticket.subject,
    identity: [
      if (ticket.orderId != null)
        ticket.trackingCode ?? SupportTicketUi.shortId(ticket.orderId!),
      '${SupportTicketUi.requesterRoleLabel(ticket.requesterRole)}: ${ticket.requesterName ?? SupportTicketUi.shortId(ticket.requesterId)}',
    ].join(' · '),
    preview: CaseMessageContent.decode(
      ticket.lastMessageBody ?? ticket.message,
    ).text,
    assignment: ticket.assignedTo == null
        ? 'Chưa tiếp nhận'
        : (ticket.assignedToName ?? 'Đã có người phụ trách'),
    time: SupportTicketUi.dateTimeLabel(ticket.updatedAt),
    status: SupportTicketUi.statusLabel(ticket.status),
    statusColor: SupportTicketUi.statusColor(ticket.status),
    icon: Icons.forum_outlined,
    onTap: onTap,
    alerts: [
      if (!ticket.status.isClosed &&
          ticket.priority == SupportTicketPriority.high)
        Text(
          'Ưu tiên cao',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
        ),
      if (ticket.responseOverdue)
        Text(
          'Quá hạn phản hồi',
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
