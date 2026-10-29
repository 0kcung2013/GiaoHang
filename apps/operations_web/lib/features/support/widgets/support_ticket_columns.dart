import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';

/// Cùng tỷ lệ cột cho tiêu đề và từng hàng, chuyển về dạng xếp khi phóng chữ.
class SupportTicketColumns extends StatelessWidget {
  const SupportTicketColumns({
    required this.subject,
    required this.status,
    required this.assignee,
    required this.updated,
    super.key,
  });

  final Widget subject;
  final Widget status;
  final Widget assignee;
  final Widget updated;

  static bool useColumns(BuildContext context, double width) =>
      width >= 900 && MediaQuery.textScalerOf(context).scale(14) <= 18.2;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(flex: 7, child: subject),
      const SizedBox(width: AppSpacing.xl),
      Expanded(flex: 3, child: status),
      const SizedBox(width: AppSpacing.xl),
      Expanded(flex: 3, child: assignee),
      const SizedBox(width: AppSpacing.xl),
      Expanded(flex: 3, child: updated),
      const SizedBox(width: AppSpacing.xl2),
    ],
  );
}

class SupportTicketQueueHeading extends StatelessWidget {
  const SupportTicketQueueHeading({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!SupportTicketColumns.useColumns(context, constraints.maxWidth)) {
        return const SizedBox.shrink();
      }
      Widget label(String value) => Text(
        value,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: SupportTicketColumns(
          subject: label(SupportTicketStrings.queueSubject),
          status: label(SupportTicketStrings.queueStatus),
          assignee: label(SupportTicketStrings.queueAssignee),
          updated: label(SupportTicketStrings.queueUpdated),
        ),
      );
    },
  );
}
