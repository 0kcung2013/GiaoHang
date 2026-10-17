import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/driver_wallet.dart';
import '../../../../core/providers/driver_wallet_providers.dart';

typedef DriverOrderWalletKey = ({String orderId, String driverId});

final driverOrderWalletTransactionsProvider = FutureProvider.autoDispose
    .family<List<DriverWalletTransaction>, DriverOrderWalletKey>((ref, key) {
      ref.watch(driverWalletChangesProvider);
      return ref
          .watch(driverWalletServiceProvider)
          .getOrderTransactions(orderId: key.orderId, driverId: key.driverId);
    });
