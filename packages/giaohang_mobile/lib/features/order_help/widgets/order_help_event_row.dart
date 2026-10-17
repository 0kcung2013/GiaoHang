import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/order_help_ui.dart';

class OrderHelpEventRow extends StatelessWidget {
  const OrderHelpEventRow({required this.event, super.key});

  final RiskReportEvent event;

  @override
  Widget build(BuildContext context) {
    final label = switch (event.eventType) {
      'created' => 'Đã gửi báo cáo',
      'assigned' => 'CSKH đã tiếp nhận',
      'status_changed' => OrderHelpUi.riskStatusLabel(event.toStatus),
      'intervention_changed' => 'Đã cập nhật hướng xử lý đơn',
      'message_added' => 'Đã thêm phản hồi',
      _ => 'Đã cập nhật báo cáo',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 17,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMedium),
                Text(
                  OrderHelpUi.dateTime(event.createdAt),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
