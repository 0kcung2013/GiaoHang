import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/customer_wallet_providers.dart';
import 'customer_wallet_states.dart';
import 'customer_wallet_surface.dart';

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
    return summary.when(
      loading: () => const CustomerWalletLoadingCard(),
      error: (_, _) => CustomerWalletErrorCard(
        onRetry: () {
          ref.invalidate(customerWalletSummaryProvider);
          ref.invalidate(customerWalletTransactionsProvider);
        },
      ),
      data: (wallet) => CustomerWalletSurface(
        summary: wallet,
        transactions: transactions.valueOrNull ?? const [],
      ),
    );
  }
}
