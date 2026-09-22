import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../data/support_order_repository.dart';
import '../models/support_order.dart';
import '../utils/support_order_ui.dart';
import '../widgets/support_order_detail_sections.dart';

Future<void> showSupportOrderDetailDialog(
  BuildContext context, {
  required SupportOrder order,
  required SupportOrderRepository repository,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        SupportOrderDetailDialog(order: order, repository: repository),
  );
}

class SupportOrderDetailDialog extends StatelessWidget {
  const SupportOrderDetailDialog({
    required this.order,
    required this.repository,
    super.key,
  });

  final SupportOrder order;
  final SupportOrderRepository repository;

  @override
  Widget build(BuildContext context) {
    final statusColor = SupportOrderUi.statusColor(order.status);
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl2,
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.md,
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          order.trackingCode,
                          style: AppTextStyles.mono.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          SupportOrderUi.statusLabel(order.status),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailSection(
                      icon: Icons.route_rounded,
                      title: 'Hành trình',
                      child: Column(
                        children: [
                          _DetailRow(
                            label: 'Điểm lấy',
                            value: order.pickupAddress,
                            color: AppColors.markerPickup,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _DetailRow(
                            label: 'Điểm giao',
                            value: order.deliveryAddress,
                            color: AppColors.markerDrop,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailSection(
                      icon: Icons.people_alt_outlined,
                      title: 'Liên hệ',
                      child: Wrap(
                        spacing: AppSpacing.xl3,
                        runSpacing: AppSpacing.md,
                        children: [
                          SupportOrderContactBlock(
                            title: 'Mã khách hàng',
                            name: order.customerId,
                          ),
                          SupportOrderContactBlock(
                            title: 'Người nhận',
                            name: order.recipientName,
                            phone: order.recipientPhone,
                          ),
                          SupportOrderContactBlock(
                            title: 'Mã tài xế',
                            name: order.driverId,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailSection(
                      icon: Icons.receipt_long_outlined,
                      title: 'Thông tin đơn',
                      child: Wrap(
                        spacing: AppSpacing.xl3,
                        runSpacing: AppSpacing.md,
                        children: [
                          SupportOrderFact(
                            label: 'Hàng hóa',
                            value: order.itemName,
                          ),
                          SupportOrderFact(
                            label: 'Tổng tiền',
                            value: formatVnd(order.totalPrice),
                          ),
                          SupportOrderFact(
                            label: 'Phí giao',
                            value: formatVnd(order.deliveryFee),
                          ),
                          SupportOrderFact(
                            label: 'Thanh toán',
                            value: SupportOrderUi.paymentLabel(
                              order.paymentMethod,
                            ),
                          ),
                          SupportOrderFact(
                            label: 'Tạo lúc',
                            value: SupportOrderUi.formatDateTime(
                              order.createdAt,
                            ),
                          ),
                          if (order.note?.trim().isNotEmpty == true)
                            SupportOrderFact(
                              label: 'Ghi chú',
                              value: order.note,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailSection(
                      icon: Icons.history_rounded,
                      title: 'Lịch sử trạng thái',
                      child: SupportOrderTimelineHistory(
                        orderId: order.id,
                        repository: repository,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(Icons.location_on_rounded, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
