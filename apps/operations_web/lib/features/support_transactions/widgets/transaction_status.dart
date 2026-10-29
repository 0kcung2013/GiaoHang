import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../utils/transaction_ui.dart';

class TransactionStatus extends StatelessWidget {
  const TransactionStatus(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = TransactionUi.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: AppRadius.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (status) {
              'completed' || 'refunded' => Icons.check_circle_outline_rounded,
              'failed' => Icons.error_outline_rounded,
              _ => Icons.schedule_rounded,
            },
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              TransactionUi.status(status),
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
