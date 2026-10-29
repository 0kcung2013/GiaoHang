import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/support_transaction.dart';
import '../utils/transaction_ui.dart';
import 'transaction_status.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    required this.transaction,
    required this.onTap,
    super.key,
  });
  final SupportTransaction transaction;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return Material(
      color: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final user = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.displayUser, style: AppTextStyles.labelMedium),
                  if (tx.userPhone != null)
                    Text(
                      tx.userPhone!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              );
              final reference = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.displayReference,
                    style: AppTextStyles.mono,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    TransactionUi.kind(tx),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (tx.trackingCode != null)
                    Text(tx.trackingCode!, style: AppTextStyles.labelSmall),
                ],
              );
              final amount = Text(
                TransactionUi.money(tx.amount),
                style: AppTextStyles.headingSmall,
              );
              if (constraints.maxWidth >= 860 &&
                  MediaQuery.textScalerOf(context).scale(1) < 1.4) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: user),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 4, child: reference),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 2, child: amount),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TransactionStatus(tx.status),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 128,
                      child: Text(
                        TransactionUi.date(tx.createdAt),
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [amount, TransactionStatus(tx.status)],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  reference,
                  const SizedBox(height: AppSpacing.md),
                  user,
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    TransactionUi.date(tx.createdAt),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
