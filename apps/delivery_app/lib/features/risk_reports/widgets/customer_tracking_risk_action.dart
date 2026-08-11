import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import 'risk_report_entry_action.dart';
import 'risk_report_sheet.dart';

class CustomerTrackingRiskAction extends StatelessWidget {
  const CustomerTrackingRiskAction({required this.order, super.key});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    if (order.status == 'pending' || order.status == 'cancelled') {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: RiskReportEntryAction(
        onPressed: () => showRiskReportSheet(
          context,
          order: order,
          role: RiskReporterRole.customer,
        ),
      ),
    );
  }
}
