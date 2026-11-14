import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../business_report_strings.dart';

Future<void> showReportReadingGuide(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.bgCard,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(BusinessReportStrings.guide, style: AppTextStyles.headingLarge),
          for (final section in [
            (BusinessReportStrings.guideCod, BusinessReportStrings.codBasis),
            (BusinessReportStrings.guideCosts, BusinessReportStrings.costBasis),
            (BusinessReportStrings.guideDates, BusinessReportStrings.dateBasis),
            (BusinessReportStrings.guideScope, BusinessReportStrings.scope),
          ]) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(section.$1, style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              section.$2,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl2),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(BusinessReportStrings.close),
          ),
        ],
      ),
    ),
  ),
);
