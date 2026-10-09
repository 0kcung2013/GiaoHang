class SupportCompletionBlocker {
  const SupportCompletionBlocker(this.message, this.riskReportId);
  final String message;
  final String riskReportId;
}

/// A preflight explanation only. The existing RPC remains authoritative.
class SupportCompletionContext {
  const SupportCompletionContext({this.orderStatus, this.blockers = const []});
  final String? orderStatus;
  final List<SupportCompletionBlocker> blockers;

  factory SupportCompletionContext.fromRows({
    String? orderStatus,
    Map<String, dynamic>? risk,
    List<Map<String, dynamic>> interventions = const [],
  }) => SupportCompletionContext(
    orderStatus: orderStatus,
    blockers: [
      if (risk != null && !['resolved', 'dismissed'].contains(risk['status']))
        SupportCompletionBlocker(
          'Sự cố liên quan chưa kết thúc.',
          risk['id'] as String,
        ),
      for (final row in interventions)
        if (['return_required', 'handoff_required'].contains(row['state']))
          SupportCompletionBlocker(
            row['state'] == 'return_required'
                ? 'Hàng đang chờ hoàn. Hoàn tất luồng hoàn hàng trước.'
                : 'Hàng đang chờ bàn giao. Xác nhận bàn giao trước.',
            row['risk_report_id'] as String,
          ),
    ],
  );
}
