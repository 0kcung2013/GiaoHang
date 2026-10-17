import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../../core/models/order_model.dart';
import '../../print_label/order_print_label_sheet.dart';
import '../../print_label/order_print_label_strings.dart';

const orderPrintLabelActionKey = Key('order-print-label-action');

class OrderPrintLabelAction extends StatelessWidget {
  const OrderPrintLabelAction({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: OrderPrintLabelStrings.actionDescription,
      child: Container(
        key: orderPrintLabelActionKey,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
          boxShadow: AppShadow.subtle,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.xl,
          child: InkWell(
            onTap: () => showOrderPrintLabelSheet(
              context: context,
              order: order,
            ),
            borderRadius: AppRadius.xl,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.lg,
                    ),
                    child: const Icon(
                      Icons.local_printshop_outlined,
                      color: AppColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          OrderPrintLabelStrings.actionTitle,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          OrderPrintLabelStrings.actionDescription,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.textOnAccent,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
