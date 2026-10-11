import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';
import 'support_queue_controls.dart';

class SupportTicketHeader extends StatelessWidget {
  const SupportTicketHeader({required this.onCreate, super.key});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SupportQueueHeading(
    title: SupportTicketStrings.ticketsTitle,
    action: OutlinedButton.icon(
      key: const Key('create-support-ticket-button'),
      onPressed: onCreate,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: AppTextStyles.labelMedium,
      ),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text(SupportTicketStrings.createTicket),
    ),
  );
}
