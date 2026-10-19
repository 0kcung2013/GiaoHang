import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/support_ticket.dart';
import 'support_request_alert_strings.dart';

class SupportRequestToast extends StatelessWidget {
  const SupportRequestToast({
    required this.ticket,
    required this.onOpen,
    required this.onDismiss,
    super.key,
  });
  final SupportTicket ticket;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Material(
      color: AppColors.bgCard,
      elevation: 8,
      shadowColor: AppColors.primary.withValues(alpha: 0.15),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    SupportRequestAlertStrings.received,
                    style: AppTextStyles.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: SupportRequestAlertStrings.dismiss,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              ticket.subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  textStyle: AppTextStyles.labelMedium,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text(SupportRequestAlertStrings.view),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
