import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket.dart';
import '../data/support_ticket_repository.dart';

abstract interface class SupportRequestAlertsRepository {
  Stream<List<SupportTicket>> watchOpenRequests();
}

class SupabaseSupportRequestAlertsRepository
    implements SupportRequestAlertsRepository {
  const SupabaseSupportRequestAlertsRepository(this.client);
  final SupabaseClient client;

  @override
  Stream<List<SupportTicket>> watchOpenRequests() => client
      .from('support_tickets')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      // Keep status-changing UPDATE events so accepted cases leave the inbox.
      // Read the existing conversation summary as well: a requester replying
      // to an automatic notice must surface as work even after another system
      // message. No notification or ticket rows are changed here.
      .asyncMap((_) => SupabaseSupportTicketRepository(client).fetchTickets());
}
