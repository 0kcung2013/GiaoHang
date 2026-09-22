import '../models/risk_report.dart';

class RiskReportAttachmentView {
  const RiskReportAttachmentView({required this.attachment, this.signedUrl});

  final RiskReportAttachment attachment;
  final String? signedUrl;
}

abstract interface class RiskReportAttachmentRepository {
  Future<List<RiskReportAttachmentView>> fetchAttachments(String reportId);
}
