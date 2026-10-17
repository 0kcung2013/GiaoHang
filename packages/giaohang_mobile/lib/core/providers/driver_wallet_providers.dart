import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_wallet.dart';
import '../services/driver_wallet_service.dart';

final driverWalletServiceProvider = Provider<DriverWalletService>((ref) {
  return DriverWalletService();
});

final driverWalletSummaryProvider =
    FutureProvider.autoDispose<DriverWalletSummary>((ref) {
      ref.watch(driverWalletChangesProvider);
      return ref.watch(driverWalletServiceProvider).getSummary();
    });

final driverWalletTransactionsProvider =
    FutureProvider.autoDispose<List<DriverWalletTransaction>>((ref) {
      ref.watch(driverWalletChangesProvider);
      return ref.watch(driverWalletServiceProvider).getTransactions(limit: 100);
    });

final driverWalletChangesProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(driverWalletServiceProvider).watchChanges();
});
