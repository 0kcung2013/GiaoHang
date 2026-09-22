import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/risk_report_strings.dart';
import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';

class RiskCaseOverview extends StatelessWidget {
  const RiskCaseOverview({required this.report, super.key});

  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSpacing.xl2,
        runSpacing: AppSpacing.md,
        children: [
          _Fact(
            label: RiskReportStrings.owner,
            value: report.assignedTo == null
                ? RiskReportStrings.unassigned
                : report.assignedToName ?? RiskReportStrings.assignedToOther,
          ),
          _Fact(
            label: RiskReportStrings.submittedAt,
            value: RiskReportUi.formatDateTime(report.createdAt),
          ),
          _Fact(
            label: RiskReportStrings.updatedAt,
            value: RiskReportUi.formatDateTime(report.updatedAt),
          ),
          if (report.responseDueAt != null)
            _Fact(
              label: RiskReportStrings.responseDeadline,
              value: RiskReportUi.formatDateTime(report.responseDueAt!),
              overdue: report.responseOverdue,
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.overdue = false});
  final String label;
  final String value;
  final bool overdue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        value,
        style: AppTextStyles.labelMedium.copyWith(
          color: overdue ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      if (overdue)
        Text(
          'Quá hạn phản hồi',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
        ),
    ],
  );
}
