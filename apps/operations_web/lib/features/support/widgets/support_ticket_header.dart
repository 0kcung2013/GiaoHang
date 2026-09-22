import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';
import '../models/support_ticket.dart';
import 'support_queue_hero.dart';

class SupportTicketHeader extends StatelessWidget {
  const SupportTicketHeader({
    required this.tickets,
    required this.onCreate,
    super.key,
  });

  final List<SupportTicket> tickets;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final open = tickets.where((item) => !item.status.isClosed).length;
    final high = tickets
        .where(
          (item) =>
              !item.status.isClosed &&
              item.priority == SupportTicketPriority.high,
        )
        .length;
    final processing = tickets
        .where((item) => item.status == SupportTicketStatus.inProgress)
        .length;
    final overdue = tickets.where((item) => item.responseOverdue).length;

    return SupportQueueHero(
      title: SupportTicketStrings.ticketsTitle,
      subtitle: SupportTicketStrings.ticketsSubtitle,
      icon: Icons.forum_rounded,
      action: SizedBox(
        height: 48,
        child: FilledButton.icon(
          key: const Key('create-support-ticket-button'),
          onPressed: onCreate,
          icon: const Icon(Icons.add_comment_rounded),
          label: const Text(SupportTicketStrings.createTicket),
        ),
      ),
      metrics: [
        SupportQueueMetric(
          label: 'Đang mở',
          value: open,
          icon: Icons.inbox_rounded,
          color: AppColors.info,
        ),
        SupportQueueMetric(
          label: 'Ưu tiên cao',
          value: high,
          icon: Icons.priority_high_rounded,
          color: AppColors.error,
        ),
        SupportQueueMetric(
          label: 'Đang xử lý',
          value: processing,
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
        ),
        SupportQueueMetric(
          label: 'Quá hạn SLA',
          value: overdue,
          icon: Icons.timer_off_rounded,
          color: AppColors.accent,
        ),
      ],
    );
  }
}
