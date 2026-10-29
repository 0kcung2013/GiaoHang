import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../order_help/data/customer_support_ticket_repository.dart';
import '../constants/customer_account_strings.dart';

abstract interface class CustomerSupportInboxRepository {
  Future<List<SupportTicket>> fetch({bool closed = false, int offset = 0});
  ParticipantSupportTicketRepository get conversations;
}

class SupabaseCustomerSupportInboxRepository
    implements CustomerSupportInboxRepository {
  SupabaseCustomerSupportInboxRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 30;
  @override
  ParticipantSupportTicketRepository get conversations =>
      SupabaseParticipantSupportTicketRepository(client: client);

  @override
  Future<List<SupportTicket>> fetch({
    bool closed = false,
    int offset = 0,
  }) async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException(CustomerAccountStrings.signIn);
    final query = client
        .from('support_tickets')
        .select(
          'id,requester_id,order_id,assigned_to,subject,message,status,priority,resolution,created_at,updated_at',
        )
        .eq('requester_id', id)
        .inFilter(
          'status',
          closed
              ? ['resolved', 'closed']
              : ['open', 'in_progress', 'waiting_customer', 'waiting_admin'],
        );
    final rows = await query
        .order('updated_at', ascending: false)
        .order('id')
        .range(offset, offset + pageSize - 1);
    return rows.map(SupportTicket.fromJson).toList();
  }
}
