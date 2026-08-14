import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/participant_risk_report_summary.dart';

abstract interface class ParticipantRiskReportQueryRepository {
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(String orderId);
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(String orderId);
  Future<ParticipantRiskReportSummary?> findActive(
    String orderId,
    RiskCategory category,
  );
  Future<List<RiskReportEvent>> fetchEvents(String reportId);
}

abstract interface class ParticipantRiskConversationRepository {
  Future<List<CaseMessage>> fetchMessages(String reportId);
  Future<void> postMessage(String reportId, String body);
}

class SupabaseParticipantRiskReportQueryRepository
    implements
        ParticipantRiskReportQueryRepository,
        ParticipantRiskConversationRepository {
  SupabaseParticipantRiskReportQueryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _selection =
      'id, order_id, category, status, title, description, resolution, '
      'triage_due_at, created_at, updated_at';

  @override
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(
    String orderId,
  ) async {
    final rows = await _client
        .from('risk_reports')
        .select(_selection)
        .eq('order_id', orderId)
        .order('updated_at', ascending: false);
    return _mapReports(rows);
  }

  @override
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(String orderId) {
    return _client
        .from('risk_reports')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('updated_at', ascending: false)
        .map(_mapReports);
  }

  @override
  Future<ParticipantRiskReportSummary?> findActive(
    String orderId,
    RiskCategory category,
  ) async {
    final row = await _client
        .from('risk_reports')
        .select(_selection)
        .eq('order_id', orderId)
        .eq('category', category.databaseValue)
        .not('status', 'in', '(resolved,dismissed)')
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : ParticipantRiskReportSummary.fromJson(row);
  }

  @override
  Future<List<RiskReportEvent>> fetchEvents(String reportId) async {
    final rows = await _client
        .from('risk_report_events')
        .select('event_type, from_status, to_status, note, created_at')
        .eq('risk_report_id', reportId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(RiskReportEvent.fromJson).toList();
  }

  List<ParticipantRiskReportSummary> _mapReports(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.map(ParticipantRiskReportSummary.fromJson).toList();
  }

  @override
  Future<List<CaseMessage>> fetchMessages(String reportId) async {
    final rows = await _client
        .from('risk_report_messages')
        .select(
          'id, risk_report_id, sender_id, sender_role_snapshot, visibility, '
          'body, created_at',
        )
        .eq('risk_report_id', reportId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows)
        .map((row) => CaseMessage.fromJson(row, caseIdKey: 'risk_report_id'))
        .toList();
  }

  @override
  Future<void> postMessage(String reportId, String body) async {
    await _client.rpc(
      'post_risk_report_message',
      params: {
        'p_report_id': reportId,
        'p_body': body.trim(),
        'p_visibility': 'public',
      },
    );
  }
}
