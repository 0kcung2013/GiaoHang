import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'business_report_strings.dart';
import 'data/business_report_repository.dart';
import 'widgets/business_report_panel.dart';
import 'widgets/report_reading_guide.dart';

class BusinessReportScreen extends StatelessWidget {
  const BusinessReportScreen({
    super.key,
    required this.customerId,
    this.repository,
  });
  final String customerId;
  final BusinessReportRepository? repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(
      backgroundColor: AppColors.bgCard,
      surfaceTintColor: AppColors.bgCard,
      foregroundColor: AppColors.primary,
      title: Text(
        BusinessReportStrings.title,
        style: AppTextStyles.headingMedium,
        maxLines: 2,
      ),
      toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 24
          ? 88
          : kToolbarHeight,
      actions: [
        IconButton(
          tooltip: BusinessReportStrings.guide,
          onPressed: () => showReportReadingGuide(context),
          icon: const Icon(Icons.info_outline_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: BusinessReportPanel(
            customerId: customerId,
            repository: repository,
            showGuide: false,
          ),
        ),
      ),
    ),
  );
}
