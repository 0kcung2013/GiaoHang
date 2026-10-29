import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_monitoring_strings.dart';
import '../constants/support_ticket_strings.dart';
import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';
import 'support_ticket_columns.dart';

/// Hàng hồ sơ có cột trên desktop; nội dung xếp dọc trên màn hình hẹp.
class SupportTicketCard extends StatelessWidget {
  const SupportTicketCard({
    required this.ticket,
    required this.onTap,
    super.key,
  });

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = SupportTicketColumns.useColumns(
        context,
        constraints.maxWidth,
      );
      final automatic = ticket.isAutomaticMonitoringNotice;
      final assignment = automatic
          ? SupportMonitoringStrings.noAcceptance
          : ticket.assignedTo == null
          ? SupportTicketStrings.unassigned
          : ticket.assignedToName ?? SupportTicketStrings.assigned;
      final assignee = Text(
        assignment,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      );
      final updated = Text(
        SupportTicketUi.dateTimeLabel(ticket.updatedAt),
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      );
      return Semantics(
        button: true,
        child: Material(
          color: AppColors.bgCard,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.md,
            side: BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: AppColors.bgLight,
            focusColor: AppColors.accentLight,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: wide
                  ? Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        SupportTicketColumns(
                          subject: _Subject(ticket: ticket),
                          status: _TicketStatus(ticket: ticket),
                          assignee: assignee,
                          updated: updated,
                        ),
                        const _OpenIndicator(),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _Subject(ticket: ticket)),
                            const SizedBox(width: AppSpacing.sm),
                            const _OpenIndicator(),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _TicketStatus(ticket: ticket),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.lg,
                          runSpacing: AppSpacing.xs,
                          children: [assignee, updated],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}

class _Subject extends StatelessWidget {
  const _Subject({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final automatic = ticket.isAutomaticMonitoringNotice;
    final preview = automatic
        ? SupportMonitoringStrings.automaticSummary
        : CaseMessageContent.decode(
            ticket.lastMessageBody ?? ticket.message,
          ).text;
    final identity = [
      if (ticket.orderId != null)
        ticket.trackingCode ?? SupportTicketUi.shortId(ticket.orderId!),
      '${SupportTicketUi.requesterRoleLabel(ticket.requesterRole)}: '
          '${ticket.requesterName ?? SupportTicketUi.shortId(ticket.requesterId)}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          automatic ? SupportMonitoringStrings.reclaimed : ticket.subject,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          identity,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (preview.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _TicketStatus extends StatelessWidget {
  const _TicketStatus({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final automatic = ticket.isAutomaticMonitoringNotice;
    final color = automatic
        ? AppColors.textSecondary
        : SupportTicketUi.statusColor(ticket.status);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: AppRadius.sm,
          ),
          child: Text(
            automatic
                ? SupportMonitoringStrings.automaticStatus
                : SupportTicketUi.statusLabel(ticket.status),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (ticket.needsSupportAttention &&
            ticket.priority == SupportTicketPriority.high)
          _Attention(
            label: SupportTicketStrings.highPriority,
            icon: Icons.flag_rounded,
            color: AppColors.error,
          ),
        if (ticket.needsReply)
          _Attention(
            label: SupportTicketStrings.needsReply,
            icon: Icons.mark_chat_unread_rounded,
            color: AppColors.accent,
          ),
      ],
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: AppSpacing.xs),
      Flexible(
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}

class _OpenIndicator extends StatelessWidget {
  const _OpenIndicator();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.chevron_right_rounded,
    size: 20,
    color: AppColors.textSecondary,
  );
}
