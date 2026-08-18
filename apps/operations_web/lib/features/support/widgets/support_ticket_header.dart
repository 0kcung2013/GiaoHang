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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl2),
            child: LayoutBuilder(
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
                if (constraints.maxWidth < 620) {
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
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final metrics = [
                  _TicketMetric(
                    label: 'Đang mở',
                    value: open,
                    icon: Icons.inbox_rounded,
                    color: AppColors.info,
                  ),
                  _TicketMetric(
                    label: 'Ưu tiên cao',
                    value: high,
                    icon: Icons.priority_high_rounded,
                    color: AppColors.error,
                  ),
                  _TicketMetric(
                    label: 'Đang xử lý',
                    value: processing,
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.warning,
                  ),
                  _TicketMetric(
                    label: 'Đã xử lý',
                    value: resolved,
                    icon: Icons.task_alt_rounded,
                    color: AppColors.success,
                  ),
                ];
                if (compact) {
                  final width = (constraints.maxWidth - AppSpacing.sm) / 2;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: metrics
                        .map((metric) => SizedBox(width: width, child: metric))
                        .toList(),
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      Expanded(child: metrics[index]),
                      if (index < metrics.length - 1)
                        const SizedBox(
                          height: 36,
                          child: VerticalDivider(
                            width: AppSpacing.xl2,
                            color: AppColors.border,
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketMetric extends StatelessWidget {
  const _TicketMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
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
