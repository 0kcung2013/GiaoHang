import 'risk_report.dart';

class RiskReportPolicy {
  const RiskReportPolicy._();

  static List<RiskStatus> allowedTransitions({
    required RiskStatus status,
    required RiskSeverity severity,
    required bool isAdmin,
  }) {
    final transitions = switch (status) {
      RiskStatus.open => [RiskStatus.investigating, RiskStatus.dismissed],
      RiskStatus.investigating => [
        RiskStatus.actionRequired,
        RiskStatus.resolved,
        RiskStatus.dismissed,
      ],
      RiskStatus.actionRequired => [
        RiskStatus.investigating,
        RiskStatus.resolved,
        RiskStatus.dismissed,
      ],
      RiskStatus.resolved || RiskStatus.dismissed => [RiskStatus.investigating],
    };

    if (severity != RiskSeverity.critical || isAdmin) return transitions;
    return transitions.where((status) => !status.isClosed).toList();
  }

  static bool requiresResolution(RiskStatus status) => status.isClosed;
}
