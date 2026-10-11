import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../order_help/data/customer_support_ticket_repository.dart';
import '../../../order_help/widgets/order_help_progress_sheet.dart';

Future<void> showDriverMonitoringReleaseDialog(
  BuildContext context, {
  String? ticketId,
}) async {
  final openCase = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_rounded, color: AppColors.warning, size: 40),
            const SizedBox(height: AppSpacing.lg),
            Text(
              DriverMonitoringStrings.reclaimedTitle,
              style: AppTextStyles.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              DriverMonitoringStrings.reclaimedBody,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (ticketId != null)
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text(DriverMonitoringStrings.support),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnDark,
                  minimumSize: const Size(48, 48),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.full,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(DriverMonitoringStrings.acknowledge),
            ),
          ],
        ),
      ),
    ),
  );
  if (openCase == true && ticketId != null && context.mounted) {
    try {
      final repository = SupabaseParticipantSupportTicketRepository();
      final ticket = await repository.fetchById(ticketId);
      if (context.mounted) {
        await showSupportTicketProgressSheet(context, ticket, repository);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(DriverMonitoringStrings.loadError)),
        );
      }
    }
  }
}
