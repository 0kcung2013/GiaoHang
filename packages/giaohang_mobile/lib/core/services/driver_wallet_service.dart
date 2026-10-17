import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_wallet.dart';

typedef DriverWalletRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);
typedef DriverWalletFunctionInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> body);
typedef DriverWalletChangeWatcher = Stream<Object?> Function();
typedef DriverOrderWalletLoader =
    Future<dynamic> Function(String orderId, String driverId);

class DriverWalletService {
  static const _orderLedgerError = 'Không tải được giao dịch ví của đơn.';

  DriverWalletService({
    SupabaseClient? client,
    DriverWalletRpcInvoker? rpcInvoker,
    DriverWalletFunctionInvoker? functionInvoker,
    DriverWalletChangeWatcher? changeWatcher,
    DriverOrderWalletLoader? orderTransactionsLoader,
  }) : _rpcInvoker = rpcInvoker ?? _defaultRpc(client),
       _functionInvoker = functionInvoker ?? _defaultFunction(client),
       _changeWatcher = changeWatcher ?? _defaultChangeWatcher(client),
       _orderTransactionsLoader =
           orderTransactionsLoader ?? _defaultOrderTransactions(client);

  final DriverWalletRpcInvoker _rpcInvoker;
  final DriverWalletFunctionInvoker _functionInvoker;
  final DriverWalletChangeWatcher _changeWatcher;
  final DriverOrderWalletLoader _orderTransactionsLoader;

  /// Full, RLS-protected ledger for this order/driver, independent of history pages.
  Future<List<DriverWalletTransaction>> getOrderTransactions({
    required String orderId,
    required String driverId,
  }) async {
    final response = await _orderTransactionsLoader(orderId, driverId);
    if (response is! List) {
      throw const DriverWalletException(_orderLedgerError);
    }
    return response
        .whereType<Map>()
        .map(
          (row) =>
              DriverWalletTransaction.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static DriverOrderWalletLoader _defaultOrderTransactions(
    SupabaseClient? client,
  ) =>
      (orderId, driverId) async => (client ?? Supabase.instance.client)
          .from('driver_wallet_transactions')
          .select()
          .eq('order_id', orderId)
          .eq('driver_id', driverId)
          .eq(
            'metadata->>purpose',
            DriverWalletTransaction.paidGoodsDepositPurpose,
          )
          .order('created_at');

  Future<DriverWalletSummary> getSummary() async {
    final response = await _rpcInvoker('get_driver_wallet_summary', const {});
    return DriverWalletSummary.fromJson(_singleRow(response));
  }

  Future<List<DriverWalletTransaction>> getTransactions({
    int limit = 30,
  }) async {
    final response = await _rpcInvoker('get_driver_wallet_transactions', {
      'p_limit': limit,
    });
    if (response is! List) {
      throw const DriverWalletException('Lịch sử ví không hợp lệ.');
    }
    return response
        .whereType<Map>()
        .map(
          (row) =>
              DriverWalletTransaction.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<Uri> createTopupPaymentUrl(int amount) async {
    if (amount < 5000 || amount > 10000000) {
      throw const DriverWalletException(
        'Số tiền nạp từ 5.000đ đến 10.000.000đ.',
      );
    }
    final response = await _functionInvoker('vnpay-create-wallet-topup', {
      'amount': amount,
    });
    if (response is! Map) {
      throw const DriverWalletException('Không nhận được liên kết VNPAY.');
    }
    final url = Uri.tryParse(response['payment_url']?.toString() ?? '');
    if (url == null || !url.hasScheme || url.host.isEmpty) {
      throw const DriverWalletException('Liên kết VNPAY không hợp lệ.');
    }
    return url;
  }

  Stream<int> watchChanges() async* {
    var revision = 0;
    await for (final _ in _changeWatcher()) {
      revision += 1;
      yield revision;
    }
  }

  static DriverWalletRpcInvoker _defaultRpc(SupabaseClient? client) {
    final supabase = client ?? Supabase.instance.client;
    return (name, params) => supabase.rpc(name, params: params);
  }

  static DriverWalletFunctionInvoker _defaultFunction(SupabaseClient? client) {
    final supabase = client ?? Supabase.instance.client;
    return (name, body) async {
      final response = await supabase.functions.invoke(name, body: body);
      if (response.status < 200 || response.status >= 300) {
        throw DriverWalletException('VNPAY trả về lỗi ${response.status}.');
      }
      return response.data;
    };
  }

  static DriverWalletChangeWatcher _defaultChangeWatcher(
    SupabaseClient? client,
  ) {
    return () => (client ?? Supabase.instance.client)
        .from('driver_wallet_transactions')
        .stream(primaryKey: ['id']);
  }

  static Map<String, dynamic> _singleRow(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.length == 1 && response.single is Map) {
      return Map<String, dynamic>.from(response.single as Map);
    }
    throw const DriverWalletException('Số dư ví không hợp lệ.');
  }
}

class DriverWalletException implements Exception {
  const DriverWalletException(this.message);

  final String message;

  @override
  String toString() => message;
}
