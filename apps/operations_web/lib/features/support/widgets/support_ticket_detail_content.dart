import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';

class SupportTicketDetailHeader extends StatelessWidget {
  const SupportTicketDetailHeader({required this.ticket, super.key});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl2,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    decoration: const BoxDecoration(color: AppColors.primary),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            size: 22,
            color: AppColors.textOnAccent,
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
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              Text(
                '#${SupportTicketUi.shortId(ticket.id)} · ${SupportTicketUi.dateTimeLabel(ticket.createdAt)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Đóng',
          onPressed: () => Navigator.pop(context),
          color: AppColors.textOnDark,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class SupportTicketContext extends StatelessWidget {
  const SupportTicketContext({required this.ticket, super.key});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    child: Wrap(
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.md,
      children: [
        _ContextItem(
          icon: SupportTicketUi.requesterRoleIcon(ticket.requesterRole),
          label: SupportTicketUi.requesterRoleLabel(ticket.requesterRole),
          value:
              ticket.requesterName ??
              SupportTicketUi.shortId(ticket.requesterId),
        ),
        _ContextItem(
          icon: Icons.inventory_2_outlined,
          label: 'Đơn hàng',
          value: ticket.orderId == null
              ? 'Chưa gắn đơn hàng'
              : SupportTicketUi.shortId(ticket.orderId!),
        ),
        _ContextItem(
          icon: Icons.support_agent_rounded,
          label: 'Người phụ trách',
          value: ticket.assignedTo == null
              ? 'Chưa có người phụ trách'
              : ticket.assignedToName ??
                    SupportTicketUi.shortId(ticket.assignedTo!),
        ),
      ],
    ),
  );
}

class SupportContentBlock extends StatelessWidget {
  const SupportContentBlock({
    required this.title,
    required this.body,
    this.color,
    super.key,
  });
  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: color ?? AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: AppTextStyles.bodyMedium),
      ],
    ),
  );
}

class _ContextItem extends StatelessWidget {
  const _ContextItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 205,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.textMuted),
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
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SupportTicketBadge extends StatelessWidget {
  const SupportTicketBadge({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: AppRadius.full,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
      ],
    ),
  );
}
