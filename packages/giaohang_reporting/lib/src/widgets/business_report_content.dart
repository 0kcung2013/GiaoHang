import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../business_report_strings.dart';
import 'report_detail_list.dart';
import 'report_summary.dart';

class BusinessReportContent extends StatefulWidget {
  const BusinessReportContent({
    super.key,
    required this.report,
    required this.onExport,
    required this.exporting,
    this.staffView = false,
  });
  final BusinessReport report;
  final VoidCallback? onExport;
  final bool exporting, staffView;

  @override
  State<BusinessReportContent> createState() => _BusinessReportContentState();
}

class _BusinessReportContentState extends State<BusinessReportContent> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ReportSummary(report: widget.report, staffView: widget.staffView),
      const SizedBox(height: AppSpacing.lg),
      LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: constraints.maxWidth >= 720 ? 240 : constraints.maxWidth,
            child: FilledButton.icon(
              onPressed: widget.onExport,
              style: FilledButton.styleFrom(
                foregroundColor: AppColors.textOnAccent,
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.all(AppSpacing.lg),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
              icon: widget.exporting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined, size: 22),
              label: Text(
                widget.exporting
                    ? BusinessReportStrings.exporting
                    : BusinessReportStrings.export,
                style: AppTextStyles.labelLarge,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl2),
      Row(
        children: [
          for (final tab in [
            BusinessReportStrings.orders,
            BusinessReportStrings.movements,
          ].indexed)
            Expanded(
              child: Semantics(
                selected: _tab == tab.$1,
                child: TextButton(
                  onPressed: () => setState(() => _tab = tab.$1),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.sm,
                    ),
                    foregroundColor: _tab == tab.$1
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tab.$2,
                        style: AppTextStyles.labelMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        height: 2,
                        color: _tab == tab.$1
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      ReportDetailList(
        key: ValueKey(_tab),
        report: widget.report,
        movements: _tab == 1,
        staffView: widget.staffView,
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        _tab == 1
            ? '${BusinessReportStrings.refundShort}: ${formatVnd(widget.report.walletRefunds)}'
            : '${BusinessReportStrings.recipientCharges}: ${formatVnd(widget.report.recipientCharges)}',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}
