import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ParticipantSupportTicketRepository {
  Future<SupportTicket> create(SupportTicketDraft draft);
  Future<List<SupportTicket>> fetchForOrder(String orderId);
  Stream<List<SupportTicket>> watchForOrder(String orderId);
}

abstract interface class ParticipantSupportConversationRepository {
  Future<List<CaseMessage>> fetchMessages(String ticketId);
  Stream<List<CaseMessage>> watchMessages(String ticketId);
  Future<void> postMessage(String ticketId, String body);
}

class SupabaseParticipantSupportTicketRepository
    implements
        ParticipantSupportTicketRepository,
        ParticipantSupportConversationRepository {
  SupabaseParticipantSupportTicketRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _selection =
      'id, order_id, requester_id, assigned_to, subject, message, '
      'risk_report_id, resolution, status, priority, first_response_at, '
      'response_due_at, escalated_at, created_at, updated_at';

  @override
  Future<SupportTicket> create(SupportTicketDraft draft) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId != draft.requesterId) {
      throw const CustomerSupportTicketException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    try {
      final row = await _client
          .from('support_tickets')
          .insert({
            'requester_id': userId,
            'created_by': userId,
            'order_id': draft.orderId,
            'subject': draft.subject.trim(),
            'message': draft.message.trim(),
            'priority': draft.priority.databaseValue,
          })
          .select(_selection)
          .single();
      return SupportTicket.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23514') {
        throw const CustomerSupportTicketException(
          'Nội dung yêu cầu chưa hợp lệ. Vui lòng kiểm tra lại.',
        );
      }
      throw const CustomerSupportTicketException(
        'Chưa thể gửi yêu cầu hỗ trợ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<List<SupportTicket>> fetchForOrder(String orderId) async {
    final rows = await _client
        .from('support_tickets')
        .select(_selection)
        .eq('order_id', orderId)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SupportTicket.fromJson).toList();
  }

  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) {
    return _client
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('updated_at', ascending: false)
        .map((rows) => rows.map(SupportTicket.fromJson).toList());
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
  Stream<List<CaseMessage>> watchMessages(String ticketId) {
    return _client
        .from('support_ticket_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => CaseMessage.fromJson(row, caseIdKey: 'ticket_id'))
              .toList(),
        );
  }

  @override
  Future<void> postMessage(String ticketId, String body) async {
    try {
      await _client.rpc(
        'post_support_ticket_message',
        params: {
          'p_ticket_id': ticketId,
          'p_body': body.trim(),
          'p_visibility': 'public',
        },
      );
    } on PostgrestException {
      throw const CustomerSupportTicketException(
        'Chưa thể gửi phản hồi. Vui lòng thử lại.',
      );
    }
  }
}

@Deprecated('Use ParticipantSupportTicketRepository')
typedef CustomerSupportTicketRepository = ParticipantSupportTicketRepository;

@Deprecated('Use ParticipantSupportConversationRepository')
typedef CustomerSupportConversationRepository =
    ParticipantSupportConversationRepository;

@Deprecated('Use SupabaseParticipantSupportTicketRepository')
typedef SupabaseCustomerSupportTicketRepository =
    SupabaseParticipantSupportTicketRepository;

class CustomerSupportTicketException implements Exception {
  const CustomerSupportTicketException(this.message);

  final String message;

  @override
  String toString() => message;
}
