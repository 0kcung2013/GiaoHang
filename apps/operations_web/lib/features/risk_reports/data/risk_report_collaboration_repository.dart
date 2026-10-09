import '../models/risk_report.dart';

abstract interface class RiskReportChangesRepository {
  Stream<void> watchReportChanges();
}

abstract interface class RiskReportDetailRepository {
  Future<RiskReport> fetchReport(String reportId);
  Stream<void> watchReport(String reportId);
  Stream<List<CaseMessage>> watchCaseMessages(String reportId);
}

abstract interface class RiskCaseConversationRepository {
  Future<List<CaseMessage>> fetchCaseMessages(String reportId);
  Future<void> postCaseMessage(
    String reportId,
    String body, {
    required CaseMessageVisibility visibility,
  });
}

abstract interface class RiskOwnershipCommandRepository {
  Future<void> takeOverReport(String reportId);
}
