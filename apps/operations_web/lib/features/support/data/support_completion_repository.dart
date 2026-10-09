import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_ticket.dart';
import '../models/support_completion_context.dart';

abstract interface class SupportCompletionRepository {
  Future<SupportCompletionContext> fetchCompletionContext(SupportTicket ticket);
}

class SupabaseSupportCompletionRepository
    implements SupportCompletionRepository {
  const SupabaseSupportCompletionRepository(this.client);
  final SupabaseClient client;

  @override
  Future<SupportCompletionContext> fetchCompletionContext(
    SupportTicket ticket,
  ) async {
    final order = ticket.orderId == null
        ? null
        : await client
              .from('orders')
              .select('status')
              .eq('id', ticket.orderId!)
              .single();
    final risk = ticket.riskReportId == null
        ? null
        : await client
              .from('risk_reports')
              .select('id,status')
              .eq('id', ticket.riskReportId!)
              .single();
    final rows = ticket.orderId == null
        ? <Map<String, dynamic>>[]
        : await client
              .from('risk_report_interventions')
              .select('risk_report_id,state')
              .eq('order_id', ticket.orderId!)
              .inFilter('state', ['return_required', 'handoff_required']);
    return SupportCompletionContext.fromRows(
      orderStatus: order?['status'] as String?,
      risk: risk,
      interventions: rows,
    );
  }
}
