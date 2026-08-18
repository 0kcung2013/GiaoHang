import 'package:flutter/material.dart';

import '../../../core/models/order_model.dart';
import '../../order_help/widgets/customer_order_help_section.dart';
import '../../returns/data/order_return_repository.dart';
import '../../returns/widgets/customer_return_status_banner.dart';

class CustomerTrackingRiskAction extends StatelessWidget {
  const CustomerTrackingRiskAction({
    required this.order,
    this.orderReturnRepository,
    super.key,
  });

  final OrderModel order;
  final OrderReturnRepository? orderReturnRepository;

  @override
  Widget build(BuildContext context) {
    final repository = orderReturnRepository ?? _createRepository();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (repository != null)
          StreamBuilder(
            stream: repository.watchForOrder(order.id),
            builder: (context, snapshot) {
              final mission = snapshot.data;
              if (mission == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CustomerReturnStatusBanner(mission: mission),
              );
            },
          ),
        CustomerOrderHelpSection(order: order, compact: true),
      ],
    );
  }

  OrderReturnRepository? _createRepository() {
    try {
      return SupabaseOrderReturnRepository();
    } on AssertionError {
      return null;
    }
  }
}
