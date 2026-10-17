import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../risk_reports/models/participant_risk_report_summary.dart';
import '../../../../risk_reports/utils/risk_recipient_return_request.dart';

/// Chờ quyết định CSKH; không cấp quyền hoàn hàng, nhận đơn hoặc thu phí.
class DriverRecipientWait {
  const DriverRecipientWait(this.report);

  static const redeliveryPerKm = 5000;
  final ParticipantRiskReportSummary report;

  bool get returnRequested =>
      RiskRecipientReturnRequest.isIncludedIn(report.description);

  static DriverRecipientWait? select({
    required String orderId,
    required String? driverUserId,
    required String orderStatus,
    required List<ParticipantRiskReportSummary> reports,
    required RiskIntervention? intervention,
  }) {
    if (driverUserId == null || orderStatus != 'delivering') return null;
    // Mọi chỉ dẫn CSKH đã chốt đều được ưu tiên hơn form chờ.
    if (intervention == null ||
        intervention.state != RiskInterventionState.awaitingTriage) {
      return null;
    }
    final eligible =
        reports
            .where(
              (report) =>
                  report.orderId == orderId &&
                  report.reportedBy == driverUserId &&
                  report.reporterRole == RiskReporterRole.driver &&
                  report.category == RiskCategory.contactIssue &&
                  !report.status.isClosed &&
                  report.id == intervention.riskReportId,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return eligible.isEmpty ? null : DriverRecipientWait(eligible.first);
  }
}
