import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../risk_reports/data/risk_report_repository.dart';
import '../../risk_reports/dialogs/risk_report_detail_dialog.dart';
import '../data/support_ticket_repository.dart';
import '../dialogs/support_ticket_detail_dialog.dart';
import '../widgets/support_workspace_scaffold.dart';
import '../widgets/support_case_queue.dart';

/// URL-addressable case; the existing editor keeps its draft during refresh.
class SupportCaseScreen extends StatefulWidget {
  const SupportCaseScreen({required this.id, this.risk = false, super.key});
  final String id;
  final bool risk;

  @override
  State<SupportCaseScreen> createState() => _SupportCaseScreenState();
}

class _SupportCaseScreenState extends State<SupportCaseScreen> {
  late Future<Widget> _content = _load();

  @override
  void didUpdateWidget(covariant SupportCaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.risk != widget.risk) {
      _content = _load();
    }
  }

  Future<Widget> _load() async {
    final client = Supabase.instance.client;
    final actor = client.auth.currentUser!.id;
    final user = await client
        .from('users')
        .select('role')
        .eq('id', actor)
        .single();
    if (widget.risk) {
      final repository = SupabaseRiskReportRepository(client);
      return RiskReportDetailDialog(
        key: ValueKey('risk-${widget.id}'),
        report: await repository.fetchReport(widget.id),
        currentUserId: actor,
        isAdmin: user['role'] == 'admin',
        repository: repository,
        embedded: true,
      );
    }
    final repository = SupabaseSupportTicketRepository(client);
    return SupportTicketDetailDialog(
      key: ValueKey('ticket-${widget.id}'),
      ticket: await repository.fetchTicket(widget.id),
      currentUserId: actor,
      isAdmin: user['role'] == 'admin',
      repository: repository,
    );
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceScaffold(
    activeSection: widget.risk
        ? SupportWorkspaceSection.risks
        : SupportWorkspaceSection.tickets,
    body: FutureBuilder<Widget>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                if (!widget.risk && constraints.maxWidth >= 1100)
                  SizedBox(
                    width: 260,
                    child: SupportCaseQueue(
                      selectedId: widget.id,
                      risk: widget.risk,
                    ),
                  ),
                Expanded(child: snapshot.data!),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Không tải được hồ sơ hoặc bạn không có quyền truy cập.',
                  style: AppTextStyles.bodyMedium,
                ),
                TextButton(
                  onPressed: () => setState(() => _content = _load()),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        );
      },
    ),
  );
}
