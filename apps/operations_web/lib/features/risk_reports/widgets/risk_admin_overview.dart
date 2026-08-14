import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/risk_report_strings.dart';
import '../data/risk_report_repository.dart';
import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';

class RiskAdminOverview extends StatelessWidget {
  const RiskAdminOverview({required this.reports, this.metrics, super.key});

  final List<RiskReport> reports;
  final RiskDashboardMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final active = reports.where((report) => !report.status.isClosed).toList();
    final activeCount = metrics?.active ?? active.length;
    final overdue =
        metrics?.slaOverdue ??
        active
            .where((report) => report.responseOverdue || report.triageOverdue)
            .length;
    final slaPercent = activeCount == 0
        ? 100
        : (((activeCount - overdue) / activeCount) * 100).round();
    final critical =
        metrics?.criticalActive ??
        active
            .where((report) => report.severity == RiskSeverity.critical)
            .length;
    final awaiting =
        metrics?.waitingAdmin ??
        active
            .where(
              (report) =>
                  report.interventionState ==
                  RiskInterventionState.awaitingTriage,
            )
            .length;
    final closed = reports.where((report) => report.status.isClosed).length;
    final closedPercent = reports.isEmpty
        ? 0
        : ((closed / reports.length) * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  RiskReportStrings.adminOverview,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
              Text(
                RiskReportStrings.adminOverviewHint,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final panelWidth = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - AppSpacing.md) / 2;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _OperationalHealthPanel(
                    width: panelWidth,
                    slaPercent: slaPercent,
                    critical: critical,
                    awaiting: awaiting,
                    closedPercent: closedPercent,
                  ),
                  _CategoryDistributionPanel(
                    width: panelWidth,
                    reports: reports,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OperationalHealthPanel extends StatelessWidget {
  const _OperationalHealthPanel({
    required this.width,
    required this.slaPercent,
    required this.critical,
    required this.awaiting,
    required this.closedPercent,
  });

  final double width;
  final int slaPercent;
  final int critical;
  final int awaiting;
  final int closedPercent;

  @override
  Widget build(BuildContext context) {
    final slaColor = slaPercent >= 90
        ? AppColors.success
        : slaPercent >= 75
        ? AppColors.warning
        : AppColors.error;
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgDarkCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  RiskReportStrings.triageSla,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
              Text(
                '$slaPercent%',
                style: AppTextStyles.headingMedium.copyWith(color: slaColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _ProgressBar(value: slaPercent / 100, color: slaColor),
          const SizedBox(height: AppSpacing.lg),
          _AdminMetricRow(
            icon: Icons.gpp_maybe_outlined,
            label: RiskReportStrings.activeCritical,
            value: '$critical',
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminMetricRow(
            icon: Icons.pending_actions_outlined,
            label: RiskReportStrings.awaitingDecision,
            value: '$awaiting',
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminMetricRow(
            icon: Icons.task_alt_rounded,
            label: RiskReportStrings.closedRate,
            value: '$closedPercent%',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _CategoryDistributionPanel extends StatelessWidget {
  const _CategoryDistributionPanel({
    required this.width,
    required this.reports,
  });

  final double width;
  final List<RiskReport> reports;

  @override
  Widget build(BuildContext context) {
    final counts = <RiskCategory, int>{};
    for (final report in reports) {
      counts.update(report.category, (value) => value + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final visible = entries.take(4).toList();
    final maximum = visible.isEmpty ? 1 : visible.first.value;

    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgDarkCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RiskReportStrings.categoryDistribution,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (visible.isEmpty)
            Text(
              RiskReportStrings.noCategoryData,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            )
          else
            for (var index = 0; index < visible.length; index++) ...[
              _CategoryBar(
                label: RiskReportUi.categoryLabel(visible[index].key),
                count: visible[index].value,
                maximum: maximum,
              ),
              if (index < visible.length - 1)
                const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _AdminMetricRow extends StatelessWidget {
  const _AdminMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
        ),
        Text(value, style: AppTextStyles.labelLarge.copyWith(color: color)),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.count,
    required this.maximum,
  });

  final String label;
  final int count;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $count báo cáo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
              Text(
                '$count',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _ProgressBar(value: count / maximum, color: AppColors.accent),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.full,
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 7,
        color: color,
        backgroundColor: AppColors.textMuted.withValues(alpha: 0.18),
      ),
    );
  }
}
