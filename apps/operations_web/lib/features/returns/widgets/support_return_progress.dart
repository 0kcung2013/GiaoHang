import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

class SupportReturnProgress extends StatelessWidget {
  const SupportReturnProgress({
    required this.mission,
    this.fallbackInstruction,
    super.key,
  });

  final OrderReturn? mission;
  final String? fallbackInstruction;

  @override
  Widget build(BuildContext context) {
    final item = mission;
    final label = switch (item?.status) {
      OrderReturnStatus.approved => 'Đã gửi lệnh cho tài xế',
      OrderReturnStatus.returning => 'Tài xế đang di chuyển về điểm hoàn',
      OrderReturnStatus.returned => 'Đã hoàn hàng và lưu bằng chứng',
      null => 'Đang đồng bộ nhiệm vụ hoàn đơn',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route_rounded, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item?.destinationAddress ??
                      fallbackInstruction ??
                      'Vui lòng chờ dữ liệu realtime.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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
