import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';
import '../models/support_ticket.dart';

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
    final resolved = tickets
        .where((item) => item.status == SupportTicketStatus.resolved)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SupportTicketStrings.ticketsTitle,
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  SupportTicketStrings.ticketsSubtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
            final action = SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('create-support-ticket-button'),
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                  textStyle: AppTextStyles.labelLarge,
                ),
                icon: const Icon(Icons.add_comment_rounded),
                label: const Text(SupportTicketStrings.createTicket),
              ),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.lg),
                  action,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.lg),
                action,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl2),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            final width =
                (constraints.maxWidth - (columns - 1) * AppSpacing.md) /
                columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _TicketMetric(
                  width: width,
                  label: 'Đang mở',
                  value: open,
                  icon: Icons.inbox_rounded,
                  color: AppColors.info,
                ),
                _TicketMetric(
                  width: width,
                  label: 'Ưu tiên cao',
                  value: high,
                  icon: Icons.priority_high_rounded,
                  color: AppColors.error,
                ),
                _TicketMetric(
                  width: width,
                  label: 'Đang xử lý',
                  value: processing,
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.warning,
                ),
                _TicketMetric(
                  width: width,
                  label: 'Đã xử lý',
                  value: resolved,
                  icon: Icons.task_alt_rounded,
                  color: AppColors.success,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TicketMetric extends StatelessWidget {
  const _TicketMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
