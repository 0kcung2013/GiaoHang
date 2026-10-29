import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/data/admin_order_repository.dart';
import '../../support/models/support_ticket.dart';
import '../../support_orders/models/support_order.dart';
import '../../support_transactions/data/transaction_repository.dart';
import '../../support_transactions/models/support_transaction.dart';

abstract interface class CustomerDossierRepository {
  Future<List<SupportOrder>> orders(String userId, {int offset = 0});
  Future<SupportOrder> order(String id);
  Future<List<SupportTicket>> tickets(String userId, {int offset = 0});
  Future<TransactionPage> transactions(
    String userId,
    TransactionGroup group, {
    SupportTransaction? before,
  });
}

class SupabaseCustomerDossierRepository implements CustomerDossierRepository {
  SupabaseCustomerDossierRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 30;

  @override
  Future<List<SupportOrder>> orders(String userId, {int offset = 0}) async {
    final rows = await client
        .from('orders')
        .select(
          'id,customer_id,tracking_code,status,pickup_address,delivery_address,total_price,delivery_fee,created_at,updated_at',
        )
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + pageSize)
        .timeout(const Duration(seconds: 15));
    return rows.map(SupportOrder.fromJson).toList();
  }

  @override
  Future<SupportOrder> order(String id) =>
      SupabaseAdminOrderRepository(client).fetchOrder(id);

  @override
  Future<List<SupportTicket>> tickets(String userId, {int offset = 0}) async {
    final rows = await client
        .from('support_tickets')
        .select(
          'id,requester_id,order_id,assigned_to,subject,message,status,priority,resolution,created_at,updated_at',
        )
        .eq('requester_id', userId)
        .order('updated_at', ascending: false)
        .order('id')
        .range(offset, offset + pageSize)
        .timeout(const Duration(seconds: 15));
    return rows.map(SupportTicket.fromJson).toList();
  }

  @override
  Future<TransactionPage> transactions(
    String userId,
    TransactionGroup group, {
    SupportTransaction? before,
  }) => SupabaseTransactionRepository(
    client,
  ).fetch(group: group, search: userId, before: before);
}
