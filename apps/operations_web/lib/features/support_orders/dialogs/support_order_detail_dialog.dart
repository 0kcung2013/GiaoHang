import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../data/support_order_repository.dart';
import '../models/support_order.dart';
import '../utils/support_order_ui.dart';
import '../widgets/support_order_detail_sections.dart';
import '../widgets/support_order_information.dart';
import '../widgets/support_order_information_components.dart';
import '../widgets/support_order_proofs.dart';

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
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
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
                    SupportOrderInformation(
                      order: order.information,
                      showIdentity: false,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SupportOrderProofs(
                      orderId: order.id,
                      repository: repository,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SupportOrderInfoSection(
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
