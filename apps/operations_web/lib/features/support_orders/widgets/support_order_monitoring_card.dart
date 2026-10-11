import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../utils/support_order_ui.dart';
import 'support_order_information_components.dart';

class SupportOrderMonitoringCard extends StatelessWidget {
  const SupportOrderMonitoringCard({required this.order, super.key});
  final RiskOrderSummary order;
  @override
  Widget build(BuildContext context) {
    final state = order.driverMonitoring;
    if (state == null) return const SizedBox.shrink();
    final incident = state.incidentReason;
    final title = state.isReclaimed
        ? 'Đã thu hồi phân công'
        : incident != null
        ? 'Sự cố hành trình cần đối chiếu'
        : 'Giám sát hành trình';
    return SupportOrderInfoSection(
      title: title,
      icon: Icons.location_searching_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (incident != null) ...[
            Text(
              incident == 'not_departed'
                  ? 'Chưa xuất phát sau 10 phút'
                  : 'Mất GPS liên tục 10 phút',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.isReclaimed
                  ? 'Đơn đã quay về tìm tài xế thay thế. Hồ sơ và hội thoại của tài xế cũ được giữ lại.'
                  : 'Giữ nguyên người giữ hàng. CSKH liên hệ xác minh và theo dõi giao hàng.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SupportOrderInfoFacts(
            children: [
              SupportOrderInfoFact(
                label: 'Nhận đơn',
                value: SupportOrderUi.formatDateTime(
                  state.acceptedAt.toLocal(),
                ),
              ),
              SupportOrderInfoFact(
                label: 'GPS hợp lệ gần nhất',
                value: state.lastReceivedAt == null
                    ? 'Chưa có mẫu mới'
                    : SupportOrderUi.formatDateTime(
                        state.lastReceivedAt!.toLocal(),
                      ),
              ),
              SupportOrderInfoFact(
                label: 'Xuất phát',
                value: state.departedAt == null
                    ? state.atPickupAt == null
                          ? 'Chưa xác nhận'
                          : 'Đã ở điểm lấy'
                    : SupportOrderUi.formatDateTime(
                        state.departedAt!.toLocal(),
                      ),
              ),
              if (state.incidentAt != null)
                SupportOrderInfoFact(
                  label: 'Phát hiện sự cố',
                  value: SupportOrderUi.formatDateTime(
                    state.incidentAt!.toLocal(),
                  ),
                ),
              if (state.reclaimedAt != null)
                SupportOrderInfoFact(
                  label: 'Thu hồi',
                  value: SupportOrderUi.formatDateTime(
                    state.reclaimedAt!.toLocal(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
