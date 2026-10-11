import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/risk_reports/data/risk_report_repository.dart';
import 'package:operations_web/features/support/data/support_order_context_repository.dart';
import 'package:operations_web/features/support_orders/data/support_order_repository.dart';
import 'package:operations_web/features/support_orders/data/support_order_contacts_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'assignment changes cannot mix a new driver contact with an old order snapshot',
    () {
      final contacts = SupportOrderContacts.fromJson({
        'orders': [
          {
            'order_id': 'order-1',
            'customer_id': 'customer',
            'driver_id': 'new-driver',
            'customer': {'full_name': 'Người gửi thật'},
            'driver': {'full_name': 'Tài xế mới'},
          },
        ],
      });
      final merged = contacts.enrichOrder(_order('order-1'));
      expect(merged['customer']['full_name'], 'Người gửi thật');
      expect(merged['driver'], isNull);
      expect(merged['driver_id'], 'driver');
    },
  );

  test(
    'order lookup hydrates contacts in one request for the entire batch',
    () async {
      final requests = <http.Request>[];
      final client = _client(requests);
      addTearDown(client.dispose);
      final orders = await SupabaseSupportOrderRepository(client).fetchOrders();
      expect(orders, hasLength(2));
      expect(orders.first.information.customer?.name, 'Người gửi thật');
      expect(orders.first.information.driver?.phone, '0988888888');
      expect(orders.first.information.itemWeightKg, 2.75);
      expect(orders.last.information.driver, isNull);
      final calls = requests.where(
        (r) => r.url.path.endsWith('/get_support_order_contacts'),
      );
      expect(calls, hasLength(1));
      expect(jsonDecode(calls.single.body), {
        'p_order_ids': ['order-1', 'order-2'],
      });
    },
  );

  test(
    'conversation context keeps order contacts and the ticket requester role',
    () async {
      final requests = <http.Request>[];
      final client = _client(requests);
      addTearDown(client.dispose);
      final data = await SupabaseSupportOrderContextRepository(
        client,
      ).fetch('order-1');
      expect(data.order.customer?.email, 'sender@example.invalid');
      expect(data.order.driver?.name, 'Tài xế hiện tại');
      expect(data.tickets.single.requesterRole, 'driver');
      expect(data.ticketLoadFailed, isFalse);
    },
  );

  test(
    'case detail hydrates its reporter even when another driver owns the order',
    () async {
      final requests = <http.Request>[];
      final client = _client(requests);
      addTearDown(client.dispose);
      final report = await SupabaseRiskReportRepository(
        client,
      ).fetchReport('report-1');
      expect(report.reporterName, 'Tài xế đã báo cáo');
      expect(report.reporterPhone, '0977777777');
      expect(report.order.driver?.name, 'Tài xế hiện tại');
      expect(report.order.itemWeightKg, 2.75);
      final rpc = requests.singleWhere(
        (r) => r.url.path.endsWith('/get_support_order_contacts'),
      );
      expect(jsonDecode(rpc.body), {
        'p_order_ids': ['order-1'],
        'p_report_id': 'report-1',
      });
    },
  );

  test('an empty search result skips the contacts RPC', () async {
    final requests = <http.Request>[];
    final client = _client(requests, empty: true);
    addTearDown(client.dispose);
    expect(await SupabaseSupportOrderRepository(client).fetchOrders(), isEmpty);
    expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
  });
}

SupabaseClient _client(List<http.Request> requests, {bool empty = false}) =>
    SupabaseClient(
      'https://supabase.example.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final Object response;
        if (request.url.path.endsWith('/get_support_order_contacts')) {
          response = {
            'orders': [
              {
                'order_id': 'order-1',
                'customer_id': 'customer',
                'driver_id': 'driver',
                'customer': {
                  'full_name': 'Người gửi thật',
                  'phone': '0901234567',
                  'email': 'sender@example.invalid',
                },
                'driver': {
                  'full_name': 'Tài xế hiện tại',
                  'phone': '0988888888',
                },
              },
              {
                'order_id': 'order-2',
                'customer_id': 'customer',
                'driver_id': null,
                'customer': {'full_name': 'Người gửi thật'},
                'driver': null,
              },
            ],
            'reporter': {
              'full_name': 'Tài xế đã báo cáo',
              'phone': '0977777777',
              'role': 'driver',
            },
          };
        } else if (request.url.path.endsWith('/get_support_ticket_contacts')) {
          response = [
            {
              'ticket_id': 'ticket-1',
              'requester_id': 'driver',
              'requester_role': 'driver',
              'requester_name': 'Tài xế của hồ sơ',
              'requester_phone': '0988888888',
            },
          ];
        } else if (request.url.path.endsWith('/risk_reports')) {
          response = {
            'id': 'report-1',
            'order_id': 'order-1',
            'reported_by': 'old-driver',
            'reporter_role_snapshot': 'driver',
            'scope': 'order',
            'category': 'cargo_issue',
            'status': 'open',
            'severity': 'medium',
            'title': 'Hàng quá cỡ',
            'description': 'Hàng thực tế quá cỡ.',
            'created_at': '2026-10-11T01:00:00Z',
            'updated_at': '2026-10-11T01:00:00Z',
            'orders': _order('order-1'),
            'reporter': null,
          };
        } else if (request.url.path.endsWith('/support_tickets')) {
          response = [
            {
              'id': 'ticket-1',
              'requester_id': 'driver',
              'requester': null,
              'subject': 'Đối chiếu hàng hóa',
              'status': 'open',
            },
          ];
        } else if (request.url.path.endsWith('/orders')) {
          response = empty
              ? []
              : request.headers.entries.any(
                  (entry) =>
                      entry.key.toLowerCase() == 'accept' &&
                      entry.value.contains('object'),
                )
              ? _order('order-1')
              : [_order('order-1'), _order('order-2')];
        } else {
          throw StateError('Unexpected request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(response),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

Map<String, dynamic> _order(String id) => {
  'id': id, 'tracking_code': 'GH-$id', 'customer_id': 'customer',
  'driver_id': id == 'order-1' ? 'driver' : null, 'status': 'picking_up',
  'pickup_address': 'Điểm lấy',
  'delivery_address': 'Điểm giao',
  'total_price': 25000,
  'created_at': '2026-10-11T01:00:00Z',
  'item_name': 'Kiện hàng',
  'item_weight_kg': 2.75,
  // The users join is empty under users_select_own for a support account.
  'customer': null, 'driver': null,
};
