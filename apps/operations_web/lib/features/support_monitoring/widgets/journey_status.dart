import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../support_orders/utils/support_order_ui.dart';

class JourneyStatus extends StatelessWidget {
  const JourneyStatus({required this.status, super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.circle, size: 8, color: SupportOrderUi.statusColor(status)),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Text(
          SupportOrderUi.statusLabel(status),
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}
