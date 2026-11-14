import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../business_report_strings.dart';
import 'report_surface.dart';

class ReportSummary extends StatelessWidget {
  const ReportSummary({
    super.key,
    required this.report,
    this.staffView = false,
  });
  final BusinessReport report;
  final bool staffView;

  @override
  Widget build(BuildContext context) => ReportSurface(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final expense = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              staffView
                  ? BusinessReportStrings.staffServiceExpense
                  : BusinessReportStrings.serviceExpense,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              formatVnd(report.senderCharges),
              style: AppTextStyles.displayLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        );
        final cod = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReportLabelValue(
              label: BusinessReportStrings.deliveredCodShort,
              value: formatVnd(report.deliveredCod),
            ),
            ReportLabelValue(
              label: BusinessReportStrings.codCreditsShort,
              value: formatVnd(report.walletCodCredits),
            ),
          ],
        );
        if (constraints.maxWidth >= 720 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
          return Row(
            children: [
              Expanded(child: expense),
              const SizedBox(width: AppSpacing.xl4),
              Expanded(child: cod),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            expense,
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1, color: AppColors.border),
            ),
            cod,
          ],
        );
      },
    ),
  );
}
