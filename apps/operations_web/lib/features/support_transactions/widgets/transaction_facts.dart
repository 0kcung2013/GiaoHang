import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../support_orders/widgets/support_order_information_components.dart';
import '../constants/transaction_strings.dart';
import '../models/support_transaction.dart';
import '../utils/transaction_ui.dart';

class TransactionFacts extends StatelessWidget {
  const TransactionFacts({
    required this.transaction,
    required this.serverNow,
    super.key,
  });
  final SupportTransaction transaction;
  final DateTime serverNow;
  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tx.isOverdue(serverNow))
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .1),
              borderRadius: AppRadius.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TransactionStrings.expiredPending,
                  style: AppTextStyles.labelMedium,
                ),
                Text(
                  TransactionStrings.pendingHint,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        SupportOrderInfoFacts(
          children: [
            SupportOrderInfoFact(
              label: TransactionStrings.user,
              value:
                  '${tx.displayUser}${tx.userPhone == null ? '' : '\n${tx.userPhone}'}',
            ),
            SupportOrderInfoFact(
              label: TransactionStrings.source,
              value: TransactionUi.source(tx.source),
            ),
            SupportOrderInfoFact(
              label: TransactionStrings.reference,
              value: tx.id,
            ),
            if (tx.providerRef != null)
              SupportOrderInfoFact(
                label: TransactionStrings.providerRef,
                value: tx.providerRef,
              ),
            if (tx.providerNo != null)
              SupportOrderInfoFact(
                label: TransactionStrings.providerNo,
                value: tx.providerNo,
              ),
            if (tx.responseCode != null)
              SupportOrderInfoFact(
                label: TransactionStrings.responseCode,
                value: tx.responseCode,
              ),
            SupportOrderInfoFact(
              label: TransactionStrings.created,
              value: TransactionUi.date(tx.createdAt),
            ),
            if (tx.completedAt != null)
              SupportOrderInfoFact(
                label: TransactionStrings.completed,
                value: TransactionUi.date(tx.completedAt),
              ),
            if (tx.expiresAt != null)
              SupportOrderInfoFact(
                label: TransactionStrings.expires,
                value: TransactionUi.date(tx.expiresAt),
              ),
            if (tx.availableDelta != null)
              SupportOrderInfoFact(
                label: TransactionStrings.availableDelta,
                value: TransactionUi.delta(tx.availableDelta),
              ),
            if (tx.heldDelta != null && tx.heldDelta != 0)
              SupportOrderInfoFact(
                label: TransactionStrings.heldDelta,
                value: TransactionUi.delta(tx.heldDelta),
              ),
            if (tx.paymentState != null)
              SupportOrderInfoFact(
                label: TransactionStrings.paymentState,
                value: TransactionUi.paymentState(tx.paymentState),
              ),
            if (tx.reason != null)
              SupportOrderInfoFact(
                label: TransactionStrings.reason,
                value: TransactionUi.reason(tx.reason),
              ),
          ],
        ),
      ],
    );
  }
}
