import 'package:flutter/material.dart';

import '../../../../../../core/models/order_model.dart';
import '../../../../../order_help/data/customer_support_ticket_repository.dart';
import '../../../../../order_help/widgets/customer_order_help_section.dart';
import '../../../../../risk_reports/data/participant_risk_report_query_repository.dart';

class OrderRiskReportSection extends StatelessWidget {
  const OrderRiskReportSection({
    required this.order,
    this.supportRepository,
    this.riskRepository,
    super.key,
  });

  final OrderModel order;
  final ParticipantSupportTicketRepository? supportRepository;
  final ParticipantRiskReportQueryRepository? riskRepository;

  @override
  Widget build(BuildContext context) {
    return CustomerOrderHelpSection(
      order: order,
      supportRepository: supportRepository,
      riskRepository: riskRepository,
    );
  }
}
