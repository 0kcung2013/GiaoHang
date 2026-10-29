import 'package:flutter/material.dart';
import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';
import '../../support/widgets/support_case_list_item.dart';

class RiskReportCard extends StatelessWidget {
  const RiskReportCard({
    required this.report,
    required this.currentUserId,
    required this.onTap,
    super.key,
  });
  final RiskReport report;
  final String currentUserId;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SupportCaseListItem(
    title: report.title,
    identity: [
      report.isSystemIncident
          ? (report.component ?? 'Hệ thống')
          : report.order.trackingCode,
      '${_reporterRoleLabel(report.reporterRole)}: ${report.reporterName ?? 'Người dùng'}',
    ].join(' · '),
    assignment: report.assignedTo == currentUserId
        ? 'Tôi phụ trách'
        : report.assignedTo == null
        ? 'Chưa tiếp nhận'
        : (report.assignedToName ?? 'Đã có người phụ trách'),
    time: RiskReportUi.formatDateTime(report.updatedAt),
    status: RiskReportUi.statusLabel(report.status),
    statusColor: RiskReportUi.statusColor(report.status),
    icon: RiskReportUi.categoryIcon(report.category),
    onTap: onTap,
  );
}

String _reporterRoleLabel(RiskReporterRole role) => switch (role) {
  RiskReporterRole.customer => 'Khách hàng',
  RiskReporterRole.driver => 'Tài xế',
  RiskReporterRole.support => 'CSKH',
  RiskReporterRole.admin => 'Admin',
  RiskReporterRole.unknown => 'Không xác định',
};
