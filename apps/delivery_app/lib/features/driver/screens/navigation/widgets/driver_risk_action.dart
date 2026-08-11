import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../risk_reports/widgets/risk_report_entry_action.dart';
import '../../../../risk_reports/widgets/risk_report_sheet.dart';

class DriverRiskAction extends StatelessWidget {
  const DriverRiskAction({required this.order, this.dark = false, super.key});

  final OrderModel order;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return RiskReportEntryAction(
      label: 'Báo cáo sự cố',
      dark: dark,
      onPressed: () => showRiskReportSheet(
        context,
        order: order,
        role: RiskReporterRole.driver,
      ),
    );
  }
}
