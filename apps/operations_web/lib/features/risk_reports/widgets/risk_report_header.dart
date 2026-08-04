import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/risk_report_strings.dart';
import '../models/risk_report.dart';

class RiskReportHeader extends StatelessWidget {
  const RiskReportHeader({
    required this.reports,
    required this.onCreate,
    super.key,
  });

  final List<RiskReport> reports;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final active = reports.where((item) => !item.status.isClosed).length;
    final critical = reports
        .where(
          (item) =>
              !item.status.isClosed && item.severity == RiskSeverity.critical,
        )
        .length;
    final unassigned = reports
        .where((item) => !item.status.isClosed && item.assignedTo == null)
        .length;
    final resolved = reports
        .where((item) => item.status == RiskStatus.resolved)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RiskReportStrings.title,
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  RiskReportStrings.subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
            final button = SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('create-risk-report-button'),
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                  textStyle: AppTextStyles.labelLarge,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(RiskReportStrings.create),
              ),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.lg),
                  button,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.lg),
                button,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl2),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            final width =
                (constraints.maxWidth - (columns - 1) * AppSpacing.md) /
                columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _MetricCard(
                  width: width,
                  label: 'Đang mở',
                  value: active,
                  icon: Icons.radar_rounded,
                  color: AppColors.info,
                ),
                _MetricCard(
                  width: width,
                  label: 'Nghiêm trọng',
                  value: critical,
                  icon: Icons.gpp_maybe_outlined,
                  color: AppColors.error,
                ),
                _MetricCard(
                  width: width,
                  label: 'Chưa nhận',
                  value: unassigned,
                  icon: Icons.person_add_alt_outlined,
                  color: AppColors.warning,
                ),
                _MetricCard(
                  width: width,
                  label: 'Đã xử lý',
                  value: resolved,
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
