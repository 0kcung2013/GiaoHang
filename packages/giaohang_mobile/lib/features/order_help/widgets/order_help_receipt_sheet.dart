import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/order_help_receipt.dart';
import '../order_help_strings.dart';

Future<void> showOrderHelpReceiptSheet(
  BuildContext context,
  OrderHelpReceipt receipt,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.42),
    builder: (_) => _OrderHelpReceiptSheet(receipt: receipt),
  );
}

class _OrderHelpReceiptSheet extends StatelessWidget {
  const _OrderHelpReceiptSheet({required this.receipt});

  final OrderHelpReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final typeLabel = receipt.type == OrderHelpRecordType.riskReport
        ? 'Báo cáo sự cố'
        : 'Yêu cầu hỗ trợ';
    final shortId = receipt.id.length <= 8
        ? receipt.id.toUpperCase()
        : receipt.id.substring(0, 8).toUpperCase();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadow.elevated,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: receipt.created
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.info.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  receipt.created
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  color: receipt.created ? AppColors.success : AppColors.info,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                receipt.created
                    ? OrderHelpStrings.receiptCreated
                    : OrderHelpStrings.receiptExisting,
                textAlign: TextAlign.center,
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$typeLabel #$shortId',
                style: AppTextStyles.mono.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        OrderHelpStrings.receiptHint,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnDark,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                ),
                child: const Text(OrderHelpStrings.viewProgress),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
