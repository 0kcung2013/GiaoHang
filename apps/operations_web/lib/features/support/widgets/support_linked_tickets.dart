import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Requester conversations remain separate from internal incident discussion.
class SupportLinkedTickets extends StatefulWidget {
  const SupportLinkedTickets({required this.riskReportId, super.key});
  final String riskReportId;

  @override
  State<SupportLinkedTickets> createState() => _SupportLinkedTicketsState();
}

class _SupportLinkedTicketsState extends State<SupportLinkedTickets> {
  late Future<List<Map<String, dynamic>>> _tickets;

  Future<List<Map<String, dynamic>>> _load() async => await Supabase
      .instance
      .client
      .from('support_tickets')
      .select('id, subject')
      .eq('risk_report_id', widget.riskReportId)
      .order('created_at');

  @override
  void initState() {
    super.initState();
    _tickets = _load();
  }

  @override
  void didUpdateWidget(covariant SupportLinkedTickets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.riskReportId != widget.riskReportId) _tickets = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _tickets,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () => setState(() => _tickets = _load()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tải lại yêu cầu liên quan'),
        );
      }
      final tickets = snapshot.data ?? const <Map<String, dynamic>>[];
      if (tickets.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yêu cầu hỗ trợ liên quan', style: AppTextStyles.labelLarge),
            for (final ticket in tickets)
              TextButton.icon(
                onPressed: () =>
                    context.push('/support-ticket/${ticket['id']}'),
                icon: const Icon(Icons.forum_outlined),
                label: Text(ticket['subject'] as String),
              ),
          ],
        ),
      );
    },
  );
}
