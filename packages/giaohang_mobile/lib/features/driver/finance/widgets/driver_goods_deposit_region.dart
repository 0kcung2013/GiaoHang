import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/providers/driver_wallet_providers.dart';
import '../models/driver_goods_deposit.dart';
import '../providers/driver_goods_deposit_provider.dart';
import 'driver_goods_deposit_panel.dart';

class DriverGoodsDepositRegion extends ConsumerWidget {
  const DriverGoodsDepositRegion({
    super.key,
    required this.order,
    this.availableBalance,
  });

  final OrderModel order;
  final int? availableBalance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (orderId: order.id, driverId: order.driverId!);
    final provider = driverOrderWalletTransactionsProvider(key);
    return ref
        .watch(provider)
        .when(
          skipLoadingOnRefresh: false,
          data: (transactions) => DriverGoodsDepositPanel(
            deposit: DriverGoodsDeposit.fromTransactions(
              orderId: order.id,
              driverId: order.driverId!,
              expectedAmount: order.driverAdvanceAmount,
              deliveryCompleted: order.status == 'delivered',
              transactions: transactions,
            ),
            receiverCollectionAmount: order.receiverCollectionAmount,
            driverNetEarning: order.driverNetEarning,
            availableBalance:
                availableBalance ??
                ref
                    .watch(driverWalletSummaryProvider)
                    .valueOrNull
                    ?.availableBalance,
          ),
          loading: () => const _LedgerFeedback(),
          error: (_, _) =>
              _LedgerFeedback(onRetry: () => ref.invalidate(provider)),
        );
  }
}

class _LedgerFeedback extends StatelessWidget {
  const _LedgerFeedback({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        if (onRetry == null)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          )
        else
          const Icon(Icons.info_outline_rounded, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            onRetry == null
                ? DriverGoodsDepositText.loading
                : DriverGoodsDepositText.unverified,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        if (onRetry != null)
          IconButton(
            onPressed: onRetry,
            tooltip: DriverGoodsDepositText.retry,
            style: IconButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.accentLight,
              minimumSize: const Size(48, 48),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
  );
}
