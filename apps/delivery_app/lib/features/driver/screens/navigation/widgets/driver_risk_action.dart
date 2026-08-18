import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../risk_reports/widgets/risk_report_entry_action.dart';
import '../../../../risk_reports/widgets/risk_report_sheet.dart';

class DriverRiskAction extends StatelessWidget {
  const DriverRiskAction({
    required this.order,
    this.initialLatitude,
    this.initialLongitude,
    this.dark = false,
    super.key,
  });

  final OrderModel order;
  final double? initialLatitude;
  final double? initialLongitude;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (order.status == 'delivered' || order.status == 'returned') {
      return const SizedBox.shrink();
    }
    return RiskReportEntryAction(
      label: 'Báo cáo sự cố',
      dark: dark,
      onPressed: () => showRiskReportSheet(
        context,
        order: order,
        role: RiskReporterRole.driver,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
      ),
    );
  }
}
