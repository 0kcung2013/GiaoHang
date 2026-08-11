import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../../core/models/order_model.dart';
import '../../../../../risk_reports/widgets/risk_report_entry_action.dart';
import '../../../../../risk_reports/widgets/risk_report_sheet.dart';

class OrderRiskReportSection extends StatelessWidget {
  const OrderRiskReportSection({required this.order, super.key});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    if (order.status == 'pending' || order.status == 'cancelled') {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.bgWarm,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cần CSKH hỗ trợ?', style: AppTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Gửi thông tin về sự cố của đơn hàng.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          RiskReportEntryAction(
            label: 'Báo cáo sự cố',
            onPressed: () => showRiskReportSheet(
              context,
              order: order,
              role: RiskReporterRole.customer,
            ),
          ),
        ],
      ),
    );
  }
}
