import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';

class SupportTicketCard extends StatelessWidget {
  const SupportTicketCard({
    required this.ticket,
    required this.onTap,
    super.key,
  });

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = SupportTicketUi.statusColor(ticket.status);
    final priorityColor = SupportTicketUi.priorityColor(ticket.priority);
    return Semantics(
      button: true,
      label: '${ticket.subject}, ${SupportTicketUi.statusLabel(ticket.status)}',
      hint: 'Mở chi tiết yêu cầu hỗ trợ',
      child: Material(
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: BorderSide(
            color: ticket.responseOverdue
                ? AppColors.error.withValues(alpha: 0.34)
                : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: AppColors.bgLight,
          focusColor: AppColors.accentLight.withValues(alpha: 0.55),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 4,
                  child: ColoredBox(color: statusColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.09),
                            borderRadius: AppRadius.md,
                          ),
                          child: Icon(
                            SupportTicketUi.statusIcon(ticket.status),
                            color: statusColor,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ticket.subject,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.headingSmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                SupportTicketUi.dateTimeLabel(ticket.updatedAt),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _TicketStatusBadge(
                          status: ticket.status,
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      ticket.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _TicketMeta(
                          icon: SupportTicketUi.requesterRoleIcon(
                            ticket.requesterRole,
                          ),
                          label:
                              '${SupportTicketUi.requesterRoleLabel(ticket.requesterRole)} '
                              '${ticket.requesterName ?? SupportTicketUi.shortId(ticket.requesterId)}',
                        ),
                        _TicketMeta(
                          icon: Icons.inventory_2_outlined,
                          label: ticket.orderId == null
                              ? 'Chưa gắn đơn'
                              : 'Đơn ${SupportTicketUi.shortId(ticket.orderId!)}',
                        ),
                        _TicketMeta(
                          icon: ticket.assignedTo == null
                              ? Icons.person_add_alt_outlined
                              : Icons.support_agent_rounded,
                          label: ticket.assignedTo == null
                              ? 'Chưa phân công'
                              : (ticket.assignedToName ?? 'Đã phân công'),
                        ),
                        if (ticket.responseOverdue)
                          const _TicketMeta(
                            icon: Icons.timer_off_outlined,
                            label: 'Quá hạn phản hồi',
                            color: AppColors.error,
                          ),
                        _TicketMeta(
                          icon: Icons.flag_outlined,
                          label:
                              'Ưu tiên ${SupportTicketUi.priorityLabel(ticket.priority)}',
                          color: priorityColor,
                        ),
                      ],
                    ),
                    if ((ticket.resolution ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.task_alt_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              ticket.resolution!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketMeta extends StatelessWidget {
  const _TicketMeta({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
      ],
    );
  }
}

class _TicketStatusBadge extends StatelessWidget {
  const _TicketStatusBadge({required this.status, required this.color});

  final SupportTicketStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(SupportTicketUi.statusIcon(status), size: 17, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            SupportTicketUi.statusLabel(status),
            style: AppTextStyles.labelSmall.copyWith(color: color),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 18, color: color),
        ],
      ),
    );
  }
}
