import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket.dart';
import 'case_pagination.dart';

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
  Stream<List<CaseMessage>> watchMessages(String ticketId);
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

abstract interface class SupportTicketDetailRepository {
  Future<SupportTicket> fetchTicket(String ticketId);
  Stream<void> watchTicket(String ticketId);
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
        SupportTicketDetailRepository,
        SupportTicketChangesRepository {
  SupabaseSupportTicketRepository(this._client);

  final SupabaseClient _client;

  static const selection =
      'id, order_id, requester_id, assigned_to, subject, message, '
      'risk_report_id, resolution, status, priority, first_response_at, '
      'response_due_at, escalated_at, created_at, updated_at, '
      'requester:users!support_tickets_requester_id_fkey(full_name, role), '
      'assignee:users!support_tickets_assigned_to_fkey(full_name), '
      'order_context:orders!support_tickets_order_id_fkey(tracking_code)';

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async =>
      SupportTicket.fromJson(
        await _client
            .from('support_tickets')
            .select(selection)
            .eq('id', ticketId)
            .single(),
      );

  @override
  Stream<void> watchTicket(String ticketId) => _client
      .from('support_tickets')
      .stream(primaryKey: ['id'])
      .eq('id', ticketId)
      .map<void>((_) {});

  @override
  Future<List<SupportTicket>> fetchTickets() async {
    final rows = await readCasePages((afterId) async {
      var query = _client
          .from('support_tickets')
          .select(
            '$selection, last_message:case_messages(body,sender_role_snapshot,visibility,created_at)',
          )
          .eq('last_message.visibility', 'public');
      if (afterId != null) query = query.gt('id', afterId);
      return await query
          .order('id', ascending: true)
          .order(
            'created_at',
            referencedTable: 'last_message',
            ascending: false,
          )
          .limit(1, referencedTable: 'last_message')
          .limit(200);
    });
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SupportTicket.fromJson).toList();
  }

  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {
    await _client.from('support_tickets').insert({
      'requester_id': draft.requesterId,
      'created_by': actorId,
      'order_id': (draft.orderId?.trim().isEmpty ?? true)
          ? null
          : draft.orderId!.trim(),
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
        .from('case_messages')
        .select(
          'id, ticket_id, sender_id, sender_role_snapshot, visibility, '
          'body, created_at',
        )
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map((row) => CaseMessage.fromJson(row, caseIdKey: 'ticket_id')).toList();
  }

  @override
  Stream<List<CaseMessage>> watchMessages(String ticketId) {
    return _client
        .from('case_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .map((row) => CaseMessage.fromJson(row, caseIdKey: 'ticket_id'))
              .toList(),
        );
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
