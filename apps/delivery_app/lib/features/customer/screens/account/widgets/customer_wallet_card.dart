import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/providers/customer_wallet_providers.dart';
import '../../../../../core/utils/money_formatter.dart';

class CustomerWalletCard extends ConsumerWidget {
  const CustomerWalletCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(customerWalletChangesProvider, (_, next) {
      if (!next.hasValue) return;
      ref.invalidate(customerWalletSummaryProvider);
      ref.invalidate(customerWalletTransactionsProvider);
    });

    final summary = ref.watch(customerWalletSummaryProvider);
    final transactions = ref.watch(customerWalletTransactionsProvider);
    final latest = transactions.valueOrNull?.firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.bgDarkCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.card,
      ),
      child: summary.when(
        loading: () => const _WalletLoading(),
        error: (_, _) => _WalletError(
          onRetry: () {
            ref.invalidate(customerWalletSummaryProvider);
            ref.invalidate(customerWalletTransactionsProvider);
          },
        ),
        data: (wallet) => Semantics(
          label:
              'Ví Khách Hàng, số dư khả dụng '
              '${formatVnd(wallet.availableBalance)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'VÍ KHÁCH HÀNG',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Số dư khả dụng',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatVnd(wallet.availableBalance),
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.08),
                  borderRadius: AppRadius.md,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.textOnDark,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        latest == null
                            ? 'Chưa có quyết toán COD'
                            : '${latest.label} • ${formatVnd(latest.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletLoading extends StatelessWidget {
  const _WalletLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 128,
      child: Center(
        child: Icon(Icons.sync_rounded, color: AppColors.accent, size: 28),
      ),
    );
  }
}

class _WalletError extends StatelessWidget {
  const _WalletError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tải lại số dư'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textOnDark),
        ),
      ),
    );
  }
}
