import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/risk_report.dart';

abstract interface class RiskReportRepository {
  Future<List<RiskReport>> fetchReports();
  Future<List<RiskReportEvent>> fetchEvents(String reportId);
  Future<void> createReport(RiskReportDraft draft);
  Future<void> assignToMe(String reportId);
  Future<void> changeStatus(
    String reportId,
    RiskStatus status, {
    String? resolution,
  });
}

class SupabaseRiskReportRepository implements RiskReportRepository {
  SupabaseRiskReportRepository(this._client);

  final SupabaseClient _client;

  static const _reportSelection = '''
    id,
    order_id,
    reported_by,
    assigned_to,
    category,
    severity,
    status,
    title,
    description,
    resolution,
    created_at,
    updated_at,
    orders!risk_reports_order_id_fkey(
      tracking_code,
      status,
      pickup_address,
      delivery_address
    )
  ''';

  @override
  Future<List<RiskReport>> fetchReports() async {
    final rows = await _client
        .from('risk_reports')
        .select(_reportSelection)
        .order('updated_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(RiskReport.fromJson).toList();
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

  @override
  Future<void> createReport(RiskReportDraft draft) async {
    final normalizedCode = draft.trackingCode.trim().toUpperCase();
    final order = await _client
        .from('orders')
        .select('id')
        .eq('tracking_code', normalizedCode)
        .maybeSingle();
    if (order == null) {
      throw const RiskReportRepositoryException('Không tìm thấy mã vận đơn.');
    }

    final actorId = _client.auth.currentUser?.id;
    if (actorId == null) {
      throw const RiskReportRepositoryException('Phiên đăng nhập đã hết hạn.');
    }

    try {
      await _client.from('risk_reports').insert({
        'order_id': order['id'],
        'reported_by': actorId,
        'updated_by': actorId,
        'category': draft.category.databaseValue,
        'severity': draft.severity.name,
        'title': draft.title.trim(),
        'description': draft.description.trim(),
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const RiskReportRepositoryException(
          'Đơn này đang có báo cáo cùng loại chưa kết thúc.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> assignToMe(String reportId) async {
    final actorId = _client.auth.currentUser?.id;
    if (actorId == null) {
      throw const RiskReportRepositoryException('Phiên đăng nhập đã hết hạn.');
    }
    await _client
        .from('risk_reports')
        .update({'assigned_to': actorId, 'updated_by': actorId})
        .eq('id', reportId);
  }

  @override
  Future<void> changeStatus(
    String reportId,
    RiskStatus status, {
    String? resolution,
  }) async {
    final actorId = _client.auth.currentUser?.id;
    if (actorId == null) {
      throw const RiskReportRepositoryException('Phiên đăng nhập đã hết hạn.');
    }
    await _client
        .from('risk_reports')
        .update({
          'status': status.databaseValue,
          'updated_by': actorId,
          if (resolution != null) 'resolution': resolution.trim(),
        })
        .eq('id', reportId);
  }
}

class RiskReportRepositoryException implements Exception {
  const RiskReportRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
