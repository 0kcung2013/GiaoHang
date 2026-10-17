import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/providers/customer_wallet_providers.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../utils/order_payment_strings.dart';

class CustomerOrderWalletPanel extends ConsumerWidget {
  const CustomerOrderWalletPanel({super.key, required this.deliveryFee});

  final int deliveryFee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(customerWalletChangesProvider, (_, next) {
      if (next.hasValue) ref.invalidate(customerWalletSummaryProvider);
    });
    final summary = ref.watch(customerWalletSummaryProvider);
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summary.when(
            loading: () => Text(
              OrderPaymentText.walletLoading,
              style: AppTextStyles.bodySmall,
            ),
            error: (_, _) => Row(
              children: [
                Expanded(
                  child: Text(
                    OrderPaymentText.walletLoadError,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(customerWalletSummaryProvider),
                  child: const Text(OrderPaymentText.walletReload),
                ),
              ],
            ),
            data: (wallet) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WalletLine(
                  label: OrderPaymentText.walletBalance,
                  amount: wallet.availableBalance,
                ),
                const SizedBox(height: AppSpacing.sm),
                _WalletLine(
                  label: OrderPaymentText.walletCharge,
                  amount: deliveryFee,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (wallet.availableBalance >= deliveryFee)
                  _WalletLine(
                    label: OrderPaymentText.walletRemaining,
                    amount: wallet.availableBalance - deliveryFee,
                  )
                else
                  Text(
                    OrderPaymentText.walletInsufficient,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            OrderPaymentText.walletTiming,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletLine extends StatelessWidget {
  const _WalletLine({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.xs,
    children: [
      Text(label, style: AppTextStyles.bodySmall),
      Text(formatVnd(amount), style: AppTextStyles.labelMedium),
    ],
  );
}
