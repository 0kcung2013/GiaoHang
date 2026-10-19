import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/support_journey_strings.dart';
import '../dialogs/support_monitoring_journey_dialog.dart';
import '../models/support_ticket.dart';

class SupportMonitoringJourneyButton extends StatelessWidget {
  const SupportMonitoringJourneyButton({required this.ticket, super.key});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.info,
      side: const BorderSide(color: AppColors.border),
      minimumSize: const Size(48, 52),
      textStyle: AppTextStyles.labelMedium,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
    ),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => SupportMonitoringJourneyDialog(ticket: ticket),
    ),
    icon: const Icon(Icons.route_rounded),
    label: const Text(SupportJourneyStrings.open),
  );
}
