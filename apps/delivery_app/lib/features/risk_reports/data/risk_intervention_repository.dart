import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class RiskInterventionRepository {
  Future<RiskIntervention?> fetchForOrder(String orderId);
  Stream<RiskIntervention?> watchForOrder(String orderId);
  Future<void> confirmCustodyResolved(String reportId, {String? note});
}

class SupabaseRiskInterventionRepository implements RiskInterventionRepository {
  SupabaseRiskInterventionRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<RiskIntervention?> fetchForOrder(String orderId) async {
    final rows = await _client
        .from('risk_report_interventions')
        .select()
        .eq('order_id', orderId)
        .limit(20);
    return _selectCurrent(List<Map<String, dynamic>>.from(rows));
  }

  @override
  Stream<RiskIntervention?> watchForOrder(String orderId) {
    return _client
        .from('risk_report_interventions')
        .stream(primaryKey: ['risk_report_id'])
        .eq('order_id', orderId)
        .map(_selectCurrent);
  }

  @override
  Future<void> confirmCustodyResolved(String reportId, {String? note}) async {
    await _client.rpc(
      'confirm_risk_custody_resolved',
      params: {'p_report_id': reportId, 'p_note': note},
    );
  }

  static RiskIntervention? _selectCurrent(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return null;
    final interventions = rows.map(RiskIntervention.fromJson).toList()
      ..sort(
        (left, right) =>
            _priority(right.state).compareTo(_priority(left.state)),
      );
    return interventions.first;
  }

  static int _priority(RiskInterventionState state) => switch (state) {
    RiskInterventionState.returnRequired ||
    RiskInterventionState.handoffRequired => 3,
    RiskInterventionState.awaitingTriage => 2,
    RiskInterventionState.heldBeforePickup => 1,
    _ => 0,
  };
}
