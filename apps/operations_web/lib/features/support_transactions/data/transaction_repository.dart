import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/data/support_ticket_repository.dart';
import '../../support/models/support_ticket.dart';
import '../../support_orders/data/support_order_contacts_loader.dart';
import '../../support_orders/data/support_order_selection.dart';
import '../../support_orders/models/support_order.dart';
import '../models/support_transaction.dart';

abstract interface class TransactionRepository {
  Future<TransactionPage> fetch({
    required TransactionGroup group,
    String search = '',
    String status = 'all',
    DateTime? from,
    DateTime? to,
    SupportTransaction? before,
  });
  Future<List<TransactionRequest>> fetchRequests(
    SupportTransaction transaction,
  );
  Future<void> createRequest(SupportTicketDraft draft);
  Future<SupportOrder> fetchOrder(String id);
}

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<TransactionPage> fetch({
    required TransactionGroup group,
    String search = '',
    String status = 'all',
    DateTime? from,
    DateTime? to,
    SupportTransaction? before,
  }) async {
    final data = Map<String, dynamic>.from(
      await _client.rpc(
            'list_support_transactions',
            params: {
              'p_group': group.name,
              'p_search': search.trim(),
              'p_status': status,
              'p_from': from?.toUtc().toIso8601String(),
              'p_to': to?.toUtc().toIso8601String(),
              'p_before_created_at': before?.createdAt
                  .toUtc()
                  .toIso8601String(),
              'p_before_key': before?.key,
              'p_limit': 30,
            },
          )
          as Map,
    );
    final rows = (data['rows'] as List)
        .map(
          (row) => SupportTransaction.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
    final hasMore = data['has_more'] as bool;
    if (hasMore && (rows.isEmpty || rows.last.key == before?.key)) {
      throw const FormatException('Transaction cursor did not advance');
    }
    return TransactionPage(
      rows: rows,
      hasMore: hasMore,
      serverNow: DateTime.parse(data['server_now'] as String),
    );
  }

  @override
  Future<List<TransactionRequest>> fetchRequests(
    SupportTransaction transaction,
  ) async {
    final marker = transaction.requestMarker;
    // IDs/source come from the staff API, never from the search input.
    final rows = await _client
        .from('support_tickets')
        .select('id,subject,status')
        .or(
          '${transaction.orderId == null ? '' : 'order_id.eq.${transaction.orderId},'}message.like.%$marker%',
        )
        .order('updated_at', ascending: false)
        .limit(30);
    return rows
        .map(
          (r) => TransactionRequest(
            id: r['id'] as String,
            subject: r['subject'] as String,
            status: r['status'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> createRequest(SupportTicketDraft draft) async {
    final actor = _client.auth.currentUser?.id;
    if (actor == null) throw const AuthException('Authentication required');
    await SupabaseSupportTicketRepository(_client).createTicket(draft, actor);
  }

  @override
  Future<SupportOrder> fetchOrder(String id) async {
    final row = await _client
        .from('orders')
        .select(supportOrderSelection)
        .eq('id', id)
        .single();
    final contacts = await SupabaseSupportOrderContactsLoader(
      _client,
    ).fetch([id]);
    return SupportOrder.fromJson(contacts.enrichOrder(row));
  }
}
