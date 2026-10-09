import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../risk_reports/data/risk_report_repository.dart';
import '../data/support_ticket_repository.dart';

/// A compact, navigable queue beside the active case on wide workstations.
class SupportCaseQueue extends StatefulWidget {
  const SupportCaseQueue({
    required this.selectedId,
    required this.risk,
    super.key,
  });
  final String selectedId;
  final bool risk;
  @override
  State<SupportCaseQueue> createState() => _SupportCaseQueueState();
}

class _SupportCaseQueueState extends State<SupportCaseQueue> {
  late Future<List<({String id, String title, String role})>> _items = _load();
  Future<List<({String id, String title, String role})>> _load() async {
    final client = Supabase.instance.client;
    if (widget.risk) {
      final reports = await SupabaseRiskReportRepository(client).fetchReports();
      reports.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return [
        for (final report in reports)
          if (!report.status.isClosed || report.id == widget.selectedId)
            (
              id: report.id,
              title: report.title,
              role: report.reporterName ?? 'Báo cáo sự cố',
            ),
      ];
    }
    final tickets = await SupabaseSupportTicketRepository(
      client,
    ).fetchTickets();
    tickets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [
      for (final ticket in tickets)
        if (!ticket.status.isClosed || ticket.id == widget.selectedId)
          (
            id: ticket.id,
            title: ticket.subject,
            role:
                '${ticket.isDriverRequester ? 'Tài xế' : 'Khách hàng'} · ${ticket.requesterName ?? ''}',
          ),
    ];
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.bgCard,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text('Cần xử lý', style: AppTextStyles.headingSmall),
              ),
              IconButton(
                tooltip: 'Tải lại hàng đợi',
                onPressed: () => setState(() => _items = _load()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() => _items = _load()),
                    child: const Text('Thử lại'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }
              final items = snapshot.data!;
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    selected: item.id == widget.selectedId,
                    selectedTileColor: AppColors.accentLight,
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium,
                    ),
                    subtitle: Text(
                      item.role,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                    onTap: item.id == widget.selectedId
                        ? null
                        : () => context.replace(
                            '/${widget.risk ? 'support-case' : 'support-ticket'}/${item.id}',
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
