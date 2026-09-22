import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';

class SupportTicketChatSidebar extends StatelessWidget {
  const SupportTicketChatSidebar({required this.ticket, super.key});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final statusColor = SupportTicketUi.statusColor(ticket.status);
    return ColoredBox(
      color: AppColors.bgCard,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Badge(
                icon: SupportTicketUi.statusIcon(ticket.status),
                label: SupportTicketUi.statusLabel(ticket.status),
                color: statusColor,
              ),
              _Badge(
                icon: Icons.flag_outlined,
                label: SupportTicketUi.priorityLabel(ticket.priority),
                color: SupportTicketUi.priorityColor(ticket.priority),
              ),
              if (ticket.responseOverdue)
                const _Badge(
                  icon: Icons.timer_off_outlined,
                  label: 'Quá hạn',
                  color: AppColors.error,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _PersonBlock(ticket: ticket),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(
            icon: Icons.inventory_2_outlined,
            label: 'Đơn hàng',
            value: ticket.orderId == null
                ? 'Chưa gắn đơn'
                : '#${SupportTicketUi.shortId(ticket.orderId!)}',
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.support_agent_rounded,
            label: 'Người phụ trách',
            value: ticket.assignedTo == null
                ? 'Chưa tiếp nhận'
                : ticket.assignedToName ??
                      SupportTicketUi.shortId(ticket.assignedTo!),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Vấn đề cần hỗ trợ',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(ticket.subject, style: AppTextStyles.headingSmall),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgWarm,
              borderRadius: AppRadius.md,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.16),
              ),
            ),
            child: Text(
              ticket.message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if ((ticket.resolution ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Kết quả xử lý',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(ticket.resolution!, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _PersonBlock extends StatelessWidget {
  const _PersonBlock({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final roleLabel = SupportTicketUi.requesterRoleLabel(ticket.requesterRole);
    return Row(
      children: [
        Container(
          width: AppSpacing.xl5,
          height: AppSpacing.xl5,
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            SupportTicketUi.requesterRoleIcon(ticket.requesterRole),
            color: AppColors.accent,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket.requesterName ??
                    SupportTicketUi.shortId(ticket.requesterId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                roleLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.textMuted),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: AppRadius.full,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
      ],
    ),
  );
}
