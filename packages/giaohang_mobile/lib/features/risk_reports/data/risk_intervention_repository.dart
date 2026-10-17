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
    return selectCurrentRiskInterventionForDriver(
      List<Map<String, dynamic>>.from(rows).map(RiskIntervention.fromJson),
    );
  }

  @override
  Stream<RiskIntervention?> watchForOrder(String orderId) {
    return _client
        .from('risk_report_interventions')
        .stream(primaryKey: ['risk_report_id'])
        .eq('order_id', orderId)
        .map(
          (rows) => selectCurrentRiskInterventionForDriver(
            rows.map(RiskIntervention.fromJson),
          ),
        );
  }

  @override
  Future<void> confirmCustodyResolved(String reportId, {String? note}) async {
    await _client.rpc(
      'confirm_risk_custody_resolved',
      params: {'p_report_id': reportId, 'p_note': note},
    );
  }
}

RiskIntervention? selectCurrentRiskInterventionForDriver(
  Iterable<RiskIntervention> values,
) {
  final interventions = values.toList();
  if (interventions.isEmpty) return null;
  interventions.sort(
    (left, right) =>
        _driverPriority(right.state).compareTo(_driverPriority(left.state)),
  );
  return interventions.first;
}

int _driverPriority(RiskInterventionState state) => switch (state) {
  RiskInterventionState.returnRequired ||
  RiskInterventionState.handoffRequired => 5,
  RiskInterventionState.heldBeforePickup || RiskInterventionState.released => 4,
  RiskInterventionState.awaitingTriage => 2,
  _ => 0,
};
