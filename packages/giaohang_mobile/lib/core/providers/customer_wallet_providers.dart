import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_wallet.dart';
import '../services/customer_wallet_service.dart';

final customerWalletServiceProvider = Provider<CustomerWalletService>((ref) {
  return CustomerWalletService();
});

final customerWalletSummaryProvider =
    FutureProvider.autoDispose<CustomerWalletSummary>((ref) {
      return ref.watch(customerWalletServiceProvider).getSummary();
    });

final customerWalletTransactionsProvider =
    FutureProvider.autoDispose<List<CustomerWalletTransaction>>((ref) {
      return ref.watch(customerWalletServiceProvider).getTransactions();
    });

final customerWalletChangesProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(customerWalletServiceProvider).watchChanges();
});
