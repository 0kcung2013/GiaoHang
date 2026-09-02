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
    this.showSeverity = true,
    super.key,
  });

  final RiskReport report;
  final String currentUserId;
  final VoidCallback onTap;
  final bool showSeverity;

  @override
  Widget build(BuildContext context) {
    final severityColor = RiskReportUi.severityColor(report.severity);
    final assignedToMe = report.assignedTo == currentUserId;
    return Semantics(
      button: true,
      label: report.isSystemIncident
          ? 'Mở báo cáo hệ thống ${report.title}'
          : 'Mở báo cáo ${report.title}, đơn ${report.order.trackingCode}',
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
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: showSeverity ? severityColor : AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showSeverity) ...[
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
                            ],
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
                            Icon(
                              report.isSystemIncident
                                  ? Icons.dns_outlined
                                  : Icons.inventory_2_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              report.isSystemIncident
                                  ? (report.component ?? 'Toàn hệ thống')
                                  : report.order.trackingCode,
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
                        _ReporterSummary(report: report),
                        if (showSeverity) ...[
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
                                        : (report.assignedToName ??
                                              RiskReportStrings
                                                  .assignedToOther),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: assignedToMe
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactReporterAvatar extends StatelessWidget {
  const _CompactReporterAvatar({required this.report});

  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    final name = report.reporterName?.trim() ?? '';
    final fallback = Center(
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.info),
      ),
    );
    return Container(
      key: const Key('risk-reporter-avatar'),
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child:
          report.reporterAvatarUrl != null &&
              report.reporterAvatarUrl!.trim().isNotEmpty
          ? Image.network(
              report.reporterAvatarUrl!,
              fit: BoxFit.cover,
              semanticLabel: 'Ảnh người gửi $name',
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

class _ReporterSummary extends StatelessWidget {
  const _ReporterSummary({required this.report});

  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    final identity = Row(
      children: [
        _CompactReporterAvatar(report: report),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (report.reporterName ?? '').isEmpty
                    ? 'Người dùng'
                    : report.reporterName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _reporterRoleLabel(report.reporterRole),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final time = Text(
      RiskReportUi.formatDateTime(report.updatedAt),
      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
    );
    final overdue = report.responseOverdue || report.triageOverdue
        ? RiskBadge(
            label: report.responseOverdue
                ? 'Quá hạn phản hồi'
                : 'Quá hạn phân loại',
            color: AppColors.error,
            icon: Icons.timer_off_outlined,
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: AppSpacing.sm),
                  time,
                ],
              ),
              if (overdue != null) ...[
                const SizedBox(height: AppSpacing.sm),
                overdue,
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            if (overdue != null) ...[
              const SizedBox(width: AppSpacing.sm),
              overdue,
            ],
            const SizedBox(width: AppSpacing.sm),
            time,
          ],
        );
      },
    );
  }
}

String _reporterRoleLabel(RiskReporterRole role) => switch (role) {
  RiskReporterRole.customer => 'Khách hàng',
  RiskReporterRole.driver => 'Tài xế',
  RiskReporterRole.support => 'CSKH',
  RiskReporterRole.admin => 'Admin',
  RiskReporterRole.unknown => 'Không xác định',
};
