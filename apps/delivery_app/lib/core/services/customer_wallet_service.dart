import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_wallet.dart';

typedef CustomerWalletRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);
typedef CustomerWalletChangeWatcher = Stream<Object?> Function();

class CustomerWalletService {
  CustomerWalletService({
    SupabaseClient? client,
    CustomerWalletRpcInvoker? rpcInvoker,
    CustomerWalletChangeWatcher? changeWatcher,
  }) : _rpcInvoker = rpcInvoker ?? _defaultRpc(client),
       _changeWatcher = changeWatcher ?? _defaultChangeWatcher(client);

  final CustomerWalletRpcInvoker _rpcInvoker;
  final CustomerWalletChangeWatcher _changeWatcher;

  Future<CustomerWalletSummary> getSummary() async {
    final response = await _rpcInvoker('get_customer_wallet_summary', const {});
    return CustomerWalletSummary.fromJson(_singleRow(response));
  }

  Future<List<CustomerWalletTransaction>> getTransactions({
    int limit = 10,
  }) async {
    final response = await _rpcInvoker('get_customer_wallet_transactions', {
      'p_limit': limit,
    });
    if (response is! List) {
      throw const CustomerWalletException(
        'Lịch sử Ví Khách Hàng không hợp lệ.',
      );
    }
    return response
        .whereType<Map>()
        .map(
          (row) => CustomerWalletTransaction.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Stream<int> watchChanges() async* {
    var revision = 0;
    await for (final _ in _changeWatcher()) {
      revision += 1;
      yield revision;
    }
  }

  static CustomerWalletRpcInvoker _defaultRpc(SupabaseClient? client) {
    final supabase = client ?? Supabase.instance.client;
    return (name, params) => supabase.rpc(name, params: params);
  }

  static CustomerWalletChangeWatcher _defaultChangeWatcher(
    SupabaseClient? client,
  ) {
    return () => (client ?? Supabase.instance.client)
        .from('customer_wallet_transactions')
        .stream(primaryKey: ['id']);
  }

  static Map<String, dynamic> _singleRow(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.length == 1 && response.single is Map) {
      return Map<String, dynamic>.from(response.single as Map);
    }
    throw const CustomerWalletException('Số dư Ví Khách Hàng không hợp lệ.');
  }
}

class CustomerWalletException implements Exception {
  const CustomerWalletException(this.message);

  final String message;

  @override
  String toString() => message;
}
