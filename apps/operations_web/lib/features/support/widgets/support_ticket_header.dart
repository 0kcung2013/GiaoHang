import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';
import 'support_queue_controls.dart';

class SupportTicketHeader extends StatelessWidget {
  const SupportTicketHeader({
    this.onCreate,
    this.title = SupportTicketStrings.ticketsTitle,
    this.onRefresh,
    this.refreshing = false,
    super.key,
  });
  final VoidCallback? onCreate;
  final String title;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) => SupportQueueHeading(
    title: title,
    action: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: refreshing
              ? SupportTicketStrings.refreshingQueue
              : SupportTicketStrings.refreshQueue,
          onPressed: refreshing ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (onCreate != null)
          FilledButton.icon(
            key: const Key('create-support-ticket-button'),
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textOnAccent,
              minimumSize: const Size(48, 48),
              textStyle: AppTextStyles.labelMedium,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(SupportTicketStrings.createTicket),
          ),
      ],
    ),
  );
}
