import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket.dart';

abstract interface class SupportTicketCommandRepository {
  Future<void> acceptTicket(String ticketId);
  Future<void> takeOverTicket(String ticketId);
  Future<void> transitionTicket(
    String ticketId,
    SupportTicketStatus status, {
    String? resolution,
  });
}

abstract interface class SupportTicketConversationRepository {
  Future<List<CaseMessage>> fetchMessages(String ticketId);
  Future<void> postMessage(
    String ticketId,
    String body, {
    required CaseMessageVisibility visibility,
  });
}

abstract interface class SupportTicketRiskRepository {
  Future<String> convertToRisk(
    String ticketId, {
    required String category,
    required String severity,
    required String title,
    required String description,
    String? component,
  });
}

abstract interface class SupportTicketChangesRepository {
  Stream<void> watchTicketChanges();
}

abstract interface class SupportTicketRepository {
  Future<List<SupportTicket>> fetchTickets();
  Future<void> createTicket(SupportTicketDraft draft, String actorId);
  Future<void> updateStatus(String ticketId, SupportTicketStatus status);
}

class SupabaseSupportTicketRepository
    implements
        SupportTicketRepository,
        SupportTicketCommandRepository,
        SupportTicketConversationRepository,
        SupportTicketRiskRepository,
        SupportTicketChangesRepository {
  SupabaseSupportTicketRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SupportTicket>> fetchTickets() async {
    final rows = await _client
        .from('support_tickets')
        .select(
          'id, order_id, customer_id, assigned_to, subject, message, '
          'risk_report_id, resolution, status, priority, first_response_at, '
          'response_due_at, escalated_at, created_at, updated_at, '
          'customer:users!support_tickets_customer_id_fkey(full_name), '
          'assignee:users!support_tickets_assigned_to_fkey(full_name)',
        )
        .order('updated_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SupportTicket.fromJson).toList();
  }

  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {
    await _client.from('support_tickets').insert({
      'customer_id': draft.customerId,
      'created_by': actorId,
      'order_id': draft.orderId.isEmpty ? null : draft.orderId,
      'subject': draft.subject.trim(),
      'message': draft.message.trim(),
      'priority': draft.priority.databaseValue,
    });
  }

  @override
  Future<void> updateStatus(String ticketId, SupportTicketStatus status) async {
    await transitionTicket(ticketId, status);
  }

  @override
  Future<void> acceptTicket(String ticketId) async {
    await _client.rpc(
      'accept_support_ticket',
      params: {'p_ticket_id': ticketId},
    );
  }

  @override
  Future<void> takeOverTicket(String ticketId) async {
    await _client.rpc(
      'takeover_support_ticket',
      params: {'p_ticket_id': ticketId},
    );
  }

  @override
  Future<void> transitionTicket(
    String ticketId,
    SupportTicketStatus status, {
    String? resolution,
  }) async {
    await _client.rpc(
      'transition_support_ticket',
      params: {
        'p_ticket_id': ticketId,
        'p_status': status.databaseValue,
        'p_resolution': resolution?.trim(),
      },
    );
  }

  @override
  Future<List<CaseMessage>> fetchMessages(String ticketId) async {
    final rows = await _client
        .from('support_ticket_messages')
        .select(
          'id, ticket_id, sender_id, sender_role_snapshot, visibility, '
          'body, created_at',
        )
        .eq('ticket_id', ticketId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(
      rows,
    ).map((row) => CaseMessage.fromJson(row, caseIdKey: 'ticket_id')).toList();
  }

  @override
  Future<void> postMessage(
    String ticketId,
    String body, {
    required CaseMessageVisibility visibility,
  }) async {
    await _client.rpc(
      'post_support_ticket_message',
      params: {
        'p_ticket_id': ticketId,
        'p_body': body.trim(),
        'p_visibility': visibility.databaseValue,
      },
    );
  }

  @override
  Future<String> convertToRisk(
    String ticketId, {
    required String category,
    required String severity,
    required String title,
    required String description,
    String? component,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'convert_support_ticket_to_risk',
      params: {
        'p_ticket_id': ticketId,
        'p_category': category,
        'p_severity': severity,
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_component': component?.trim(),
      },
    );
    return row['id']?.toString() ?? '';
  }

  @override
  Stream<void> watchTicketChanges() {
    return _client
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .skip(1)
        .map<void>((_) {});
  }
}
