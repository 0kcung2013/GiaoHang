import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support_orders/data/support_order_selection.dart';
import '../../support_orders/data/support_order_contacts_loader.dart';
import 'support_ticket_contacts_loader.dart';

abstract interface class SupportOrderContextRepository {
  Future<SupportOrderContextData> fetch(String orderId);
}

abstract interface class SupportOrderContextChangesRepository {
  Stream<void> watchOrder(String orderId);
}

class SupportOrderContextData {
  const SupportOrderContextData({
    required this.order,
    this.tickets = const [],
    this.ticketLoadFailed = false,
  });
  final RiskOrderSummary order;
  final List<SupportOrderLinkedTicket> tickets;
  final bool ticketLoadFailed;
}

class SupportOrderLinkedTicket {
  const SupportOrderLinkedTicket({
    required this.id,
    required this.subject,
    required this.status,
    this.requesterId,
    this.requesterRole,
  });
  final String id;
  final String subject;
  final String status;
  final String? requesterId;
  final String? requesterRole;
  bool get isClosed => status == 'resolved' || status == 'closed';

  factory SupportOrderLinkedTicket.fromJson(Map<String, dynamic> row) =>
      SupportOrderLinkedTicket(
        id: row['id'].toString(),
        subject: row['subject']?.toString() ?? '',
        status: row['status']?.toString() ?? '',
        requesterId: row['requester_id']?.toString(),
        requesterRole: row['requester']?['role']?.toString(),
      );
}

class SupabaseSupportOrderContextRepository
    implements
        SupportOrderContextRepository,
        SupportOrderContextChangesRepository {
  SupabaseSupportOrderContextRepository(this._client);
  final SupabaseClient _client;

  @override
  Stream<void> watchOrder(String orderId) => _client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('id', orderId)
      .skip(1)
      .map<void>((_) {});

  @override
  Future<SupportOrderContextData> fetch(String orderId) async {
    final row = await _client
        .from('orders')
        .select(supportOrderSelection)
        .eq('id', orderId)
        .single();
    final contacts = await SupabaseSupportOrderContactsLoader(
      _client,
    ).fetch([orderId]);
    final order = RiskOrderSummary.fromJson(contacts.enrichOrder(row));
    try {
      final tickets = await _client
          .from('support_tickets')
          .select(
            'id,requester_id,subject,status,requester:users!support_tickets_requester_id_fkey(role)',
          )
          .eq('order_id', orderId)
          .order('updated_at', ascending: false);
      final enriched = await SupportTicketContactsLoader(
        _client,
      ).enrich(tickets);
      return SupportOrderContextData(
        order: order,
        tickets: enriched
            .map(
              (ticket) => SupportOrderLinkedTicket.fromJson({
                ...ticket,
                'requester':
                    ticket['requester'] ??
                    {
                      'role': ticket['requester_id'] == order.customerId
                          ? 'customer'
                          : ticket['requester_id'] == order.driverId
                          ? 'driver'
                          : null,
                    },
              }),
            )
            .toList(),
      );
    } catch (_) {
      // Lỗi tải hội thoại không được làm mất dữ liệu đơn đã đọc thành công.
      return SupportOrderContextData(order: order, ticketLoadFailed: true);
    }
  }
}
