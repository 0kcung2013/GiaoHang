import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import 'risk_reports_view.dart';

class SupportRiskReportsScreen extends StatelessWidget {
  const SupportRiskReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          'Báo cáo rủi ro',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        scrolledUnderElevation: 0.5,
      ),
      body: const RiskReportsView(isAdmin: false),
    );
  }
}
