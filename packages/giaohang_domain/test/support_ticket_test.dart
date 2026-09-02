import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:test/test.dart';

void main() {
  test('parses a driver requester from the shared support model', () {
    final ticket = SupportTicket.fromJson({
      'id': 'ticket-1',
      'requester_id': 'driver-1',
      'requester': {'full_name': 'Tài xế A', 'role': 'driver'},
      'subject': 'Trao đổi với CSKH',
      'message': 'Cần hỗ trợ giao đơn.',
      'status': 'open',
      'priority': 'normal',
      'created_at': '2026-08-28T00:00:00Z',
      'updated_at': '2026-08-28T00:00:00Z',
    });

    expect(ticket.requesterId, 'driver-1');
    expect(ticket.requesterName, 'Tài xế A');
    expect(ticket.isDriverRequester, isTrue);
    expect(ticket.toJson()['requester_id'], 'driver-1');
  });

  test('keeps reading legacy customer payloads during migration', () {
    final draft = SupportTicketDraft.fromJson({
      'customer_id': 'customer-1',
      'order_id': 'order-1',
      'subject': 'Thanh toán',
      'message': 'Cần kiểm tra phí.',
      'priority': 'normal',
    });

    expect(draft.requesterId, 'customer-1');
    expect(draft.toJson()['requester_id'], 'customer-1');
  });
}
