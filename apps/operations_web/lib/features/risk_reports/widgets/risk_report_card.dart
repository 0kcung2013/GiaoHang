import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/risk_report_strings.dart';
import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';
import 'risk_badge.dart';

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
  Widget build(BuildContext context) {
    final severityColor = RiskReportUi.severityColor(report.severity);
    final assignedToMe = report.assignedTo == currentUserId;
    return Semantics(
      button: true,
      label: 'Mở báo cáo ${report.title}, đơn ${report.order.trackingCode}',
      child: Material(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.subtle,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RiskBadge(
                                label: RiskReportUi.severityLabel(
                                  report.severity,
                                ),
                                color: severityColor,
                                icon: RiskReportUi.severityIcon(
                                  report.severity,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              RiskBadge(
                                label: RiskReportUi.statusLabel(report.status),
                                color: RiskReportUi.statusColor(report.status),
                                icon: RiskReportUi.statusIcon(report.status),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            report.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headingSmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                report.order.trackingCode,
                                style: AppTextStyles.mono.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Icon(
                                RiskReportUi.categoryIcon(report.category),
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  RiskReportUi.categoryLabel(report.category),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.bgLight,
                              borderRadius: AppRadius.md,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  assignedToMe
                                      ? Icons.person_rounded
                                      : Icons.person_add_alt_outlined,
                                  size: 17,
                                  color: assignedToMe
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    assignedToMe
                                        ? RiskReportStrings.assignedToYou
                                        : report.assignedTo == null
                                        ? RiskReportStrings.unassigned
                                        : 'Đã có người phụ trách',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: assignedToMe
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  RiskReportUi.formatDateTime(report.updatedAt),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
