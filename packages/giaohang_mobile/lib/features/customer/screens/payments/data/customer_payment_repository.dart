import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_payment.dart';

typedef CustomerPaymentRange = ({DateTime start, DateTime end});

abstract interface class CustomerPaymentRepository {
  Future<List<CustomerPayment>> fetch(CustomerPaymentRange range);
}

class SupabaseCustomerPaymentRepository implements CustomerPaymentRepository {
  SupabaseCustomerPaymentRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 100;
  static const timeout = Duration(seconds: 20);

  @override
  Future<List<CustomerPayment>> fetch(CustomerPaymentRange range) async {
    final actor = client.auth.currentUser?.id;
    if (actor == null || !range.start.isBefore(range.end)) {
      throw const FormatException();
    }
    final sources = await Future.wait([
      for (final method in CustomerPaymentMethod.values)
        _read(method, actor, range),
    ]);
    if (client.auth.currentUser?.id != actor) throw const FormatException();
    return sources.expand((source) => source).toList()..sort((a, b) {
      final date = b.createdAt.compareTo(a.createdAt);
      return date == 0 ? b.key.compareTo(a.key) : date;
    });
  }

  Future<List<CustomerPayment>> _read(
    CustomerPaymentMethod method,
    String actor,
    CustomerPaymentRange range,
  ) async {
    final wallet = method == CustomerPaymentMethod.wallet;
    final table = wallet
        ? 'customer_wallet_transactions'
        : 'order_payment_sessions';
    final result = <String, CustomerPayment>{};
    Map<String, dynamic>? last;
    final start = _utc(range.start);
    final end = _utc(range.end);
    while (true) {
      var query = client
          .from(table)
          .select(
            'id,customer_id,order_id,status,amount,created_at,'
            '${wallet ? 'transaction_type,metadata' : 'provider,provider_txn_ref'},'
            'order:orders!${table}_order_id_fkey(tracking_code)',
          )
          .eq('customer_id', actor)
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String());
      query = wallet
          ? query.eq('transaction_type', 'delivery_fee_payment')
          : query.eq('provider', 'vnpay');
      if (last != null) {
        final timestamp = DateTime.parse(
          last['created_at'] as String,
        ).toUtc().toIso8601String();
        query = query.or(
          'created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.${last['id']})',
        );
      }
      final rows = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(pageSize)
          .timeout(timeout);
      if (client.auth.currentUser?.id != actor) throw const FormatException();
      for (final row in rows) {
        final payment = CustomerPayment.fromJson(row, method);
        if (row['customer_id'] != actor ||
            payment.id.isEmpty ||
            payment.amount <= 0 ||
            payment.createdAt.isBefore(start) ||
            !payment.createdAt.isBefore(end) ||
            (wallet && row['transaction_type'] != 'delivery_fee_payment') ||
            (!wallet && row['provider'] != 'vnpay')) {
          throw const FormatException();
        }
        result[payment.id] = payment;
      }
      if (rows.length < pageSize) return result.values.toList();
      final next = rows.last;
      if (next['id'] == last?['id']) throw const FormatException();
      last = next;
    }
  }

  // Calendar fields here represent Vietnam wall-clock time, not device time.
  DateTime _utc(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).subtract(VietnamTime.utcOffset);
}
