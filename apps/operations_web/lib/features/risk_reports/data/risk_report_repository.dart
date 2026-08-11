import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/risk_message_evidence.dart';
import '../models/risk_report.dart';

abstract interface class RiskReportRepository {
  Future<List<RiskReport>> fetchReports();
  Future<List<RiskReportEvent>> fetchEvents(String reportId);
  Future<List<RiskOrderMessage>> fetchOrderMessages(String orderId);
  Future<List<RiskMessageEvidence>> fetchMessageEvidence(String reportId);
  Future<List<RiskMessageEvidence>> attachMessageEvidence(
    String reportId,
    List<String> messageIds,
  );
  Future<void> createReport(RiskReportDraft draft);
  Future<void> assignToMe(String reportId);
  Future<void> changeStatus(
    String reportId,
    RiskStatus status, {
    String? resolution,
  });
}

class RiskReportAttachmentView {
  const RiskReportAttachmentView({required this.attachment, this.signedUrl});

  final RiskReportAttachment attachment;
  final String? signedUrl;
}

abstract interface class RiskReportAttachmentRepository {
  Future<List<RiskReportAttachmentView>> fetchAttachments(String reportId);
}

abstract interface class RiskInterventionCommandRepository {
  Future<RiskIntervention?> fetchIntervention(String reportId);
  Future<void> acceptReport(String reportId);
  Future<void> holdBeforePickup(String reportId, {String? instruction});
  Future<void> decideOperation(
    String reportId,
    RiskInterventionState decision, {
    String? instruction,
  });
  Future<void> confirmCustodyResolved(String reportId, {String? note});
  Future<void> resumeHeldOrder(String reportId);
  Future<void> addInternalNote(String reportId, String body);
}

class SupabaseRiskReportRepository
    implements
        RiskReportRepository,
        RiskReportAttachmentRepository,
        RiskInterventionCommandRepository {
  SupabaseRiskReportRepository(this._client);

  final SupabaseClient _client;

  static const _reportSelection = '''
    id,
    order_id,
    reported_by,
    assigned_to,
    reporter_role_snapshot,
    triage_due_at,
    escalated_at,
    category,
    severity,
    status,
    title,
    description,
    resolution,
    created_at,
    updated_at,
    reporter:users!risk_reports_reported_by_fkey(
      full_name,
      role
    ),
    intervention:risk_report_interventions!risk_report_interventions_risk_report_id_fkey(
      decision_due_at,
      escalated_at,
      state
    ),
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
    ).map(_mergeInterventionTriage).map(RiskReport.fromJson).toList();
  }

  Map<String, dynamic> _mergeInterventionTriage(Map<String, dynamic> row) {
    final result = Map<String, dynamic>.of(row);
    final rawIntervention = row['intervention'];
    final Map<String, dynamic>? intervention = switch (rawIntervention) {
      Map<String, dynamic>() => rawIntervention,
      Map() => Map<String, dynamic>.from(rawIntervention),
      List() when rawIntervention.isNotEmpty => Map<String, dynamic>.from(
        rawIntervention.first as Map,
      ),
      _ => null,
    };
    if (intervention == null) return result;

    result['triage_due_at'] ??= intervention['decision_due_at'];
    result['escalated_at'] ??= intervention['escalated_at'];
    return result;
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
  Future<List<RiskReportAttachmentView>> fetchAttachments(
    String reportId,
  ) async {
    final rows = await _client
        .from('risk_report_attachments')
        .select()
        .eq('risk_report_id', reportId)
        .order('created_at');
    final result = <RiskReportAttachmentView>[];
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final attachment = RiskReportAttachment.fromJson(row);
      String? signedUrl;
      if (attachment.evidenceType == RiskEvidenceType.photo &&
          attachment.storagePath != null) {
        signedUrl = await _client.storage
            .from('risk-report-evidence')
            .createSignedUrl(attachment.storagePath!, 3600);
      }
      result.add(
        RiskReportAttachmentView(attachment: attachment, signedUrl: signedUrl),
      );
    }
    return result;
  }

  @override
  Future<RiskIntervention?> fetchIntervention(String reportId) async {
    final row = await _client
        .from('risk_report_interventions')
        .select()
        .eq('risk_report_id', reportId)
        .maybeSingle();
    return row == null ? null : RiskIntervention.fromJson(row);
  }

  @override
  Future<void> acceptReport(String reportId) async {
    await _client.rpc('accept_risk_report', params: {'p_report_id': reportId});
  }

  @override
  Future<void> holdBeforePickup(String reportId, {String? instruction}) async {
    await _client.rpc(
      'hold_risk_order_before_pickup',
      params: {'p_report_id': reportId, 'p_instruction': instruction},
    );
  }

  @override
  Future<void> decideOperation(
    String reportId,
    RiskInterventionState decision, {
    String? instruction,
  }) async {
    await _client.rpc(
      'decide_risk_delivery_operation',
      params: {
        'p_report_id': reportId,
        'p_decision': decision.databaseValue,
        'p_instruction': instruction,
      },
    );
  }

  @override
  Future<void> confirmCustodyResolved(String reportId, {String? note}) async {
    await _client.rpc(
      'confirm_risk_custody_resolved',
      params: {'p_report_id': reportId, 'p_note': note},
    );
  }

  @override
  Future<void> resumeHeldOrder(String reportId) async {
    await _client.rpc(
      'resume_risk_held_order',
      params: {'p_report_id': reportId},
    );
  }

  @override
  Future<void> addInternalNote(String reportId, String body) async {
    await _client.rpc(
      'add_risk_report_note',
      params: {'p_report_id': reportId, 'p_body': body},
    );
  }

  @override
  Future<List<RiskOrderMessage>> fetchOrderMessages(String orderId) async {
    final rows = await _client
        .from('order_messages')
        .select('id, sender_id, message_type, body, created_at')
        .eq('order_id', orderId)
        .order('created_at')
        .limit(200);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(RiskOrderMessage.fromJson).toList();
  }

  @override
  Future<List<RiskMessageEvidence>> fetchMessageEvidence(
    String reportId,
  ) async {
    final rows = await _client
        .from('risk_report_message_evidence')
        .select()
        .eq('risk_report_id', reportId)
        .order('sent_at_snapshot');
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(RiskMessageEvidence.fromJson).toList();
  }

  @override
  Future<List<RiskMessageEvidence>> attachMessageEvidence(
    String reportId,
    List<String> messageIds,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'attach_risk_report_message_evidence',
      params: {'p_risk_report_id': reportId, 'p_message_ids': messageIds},
    );
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(RiskMessageEvidence.fromJson).toList();
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
    await acceptReport(reportId);
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
