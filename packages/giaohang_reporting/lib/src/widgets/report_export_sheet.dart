import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../business_report_strings.dart';
import '../export/business_report_export.dart';
import '../utils/report_format.dart';
import 'report_surface.dart';

Future<BusinessReportFormat?> showReportExportSheet(
  BuildContext context,
  BusinessReport report,
) => showModalBottomSheet<BusinessReportFormat>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.bgCard,
  constraints: BoxConstraints(
    maxWidth: 600,
    maxHeight: MediaQuery.sizeOf(context).height * .9,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  BusinessReportStrings.export,
                  style: AppTextStyles.headingMedium,
                ),
              ),
              IconButton(
                tooltip: BusinessReportStrings.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
          Text(
            reportPeriod(report),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final option in [
            (
              BusinessReportFormat.excel,
              BusinessReportStrings.excel,
              BusinessReportStrings.excelHint,
              Icons.table_chart_outlined,
            ),
            (
              BusinessReportFormat.pdf,
              BusinessReportStrings.pdf,
              BusinessReportStrings.pdfHint,
              Icons.picture_as_pdf_outlined,
            ),
          ]) ...[
            ReportSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                leading: Icon(option.$4, color: AppColors.primary),
                title: Text(option.$2, style: AppTextStyles.labelLarge),
                subtitle: Text(
                  option.$3,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, option.$1),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.lg),
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: AppColors.primary,
            title: Text(
              BusinessReportStrings.statementProfile,
              style: AppTextStyles.labelMedium,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      report.name,
                      style: AppTextStyles.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      report.address,
                      style: AppTextStyles.bodyMedium,
                    ),
                    ReportLabelValue(
                      label: BusinessReportStrings.taxCode,
                      value: report.taxCode ?? BusinessReportStrings.missing,
                    ),
                    Text(
                      BusinessReportStrings.currentProfile,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${BusinessReportStrings.generated}: ${reportDate(report.generatedAt)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            BusinessReportStrings.exportScope,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  ),
);
