import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../risk_reports/models/participant_risk_report_summary.dart';

/// Chỉ là trạng thái trình bày; không cấp quyền nhận đơn hoặc thu phí.
class DriverRecipientWait {
  const DriverRecipientWait(this.report);

  static const window = Duration(minutes: 15);
  static const redeliveryPerKm = 5000;
  final ParticipantRiskReportSummary report;

  DateTime get endsAt => report.createdAt.add(window);

  Duration remainingAt(DateTime serverNow) {
    final remaining = endsAt.difference(serverNow);
    if (remaining.isNegative) return Duration.zero;
    return remaining > window ? window : remaining;
  }

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
