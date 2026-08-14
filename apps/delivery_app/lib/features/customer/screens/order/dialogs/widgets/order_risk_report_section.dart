import 'package:flutter/material.dart';

import '../../../../../../core/models/order_model.dart';
import '../../../../../order_help/widgets/customer_order_help_section.dart';

class OrderRiskReportSection extends StatelessWidget {
  const OrderRiskReportSection({required this.order, super.key});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return CustomerOrderHelpSection(order: order);
  }
}
