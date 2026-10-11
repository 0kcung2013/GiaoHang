import 'dart:convert';

import 'package:delivery_app/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:delivery_app/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'report reply uses risk RPC and remains outside support ticket chat',
    () async {
      final stored = <Map<String, dynamic>>[];
      final transport = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST') {
          expect(path, '/rest/v1/rpc/post_risk_report_message');
          final params = jsonDecode(request.body) as Map<String, dynamic>;
          expect(params, {
            'p_report_id': 'risk-1',
            'p_body': 'hello',
            'p_visibility': 'public',
          });
          stored.add({
            'id': 'saved-message',
            'ticket_id': null,
            'risk_report_id': params['p_report_id'],
            'body': params['p_body'],
            'visibility': params['p_visibility'],
            'sender_id': 'driver',
            'sender_role_snapshot': 'driver',
            'created_at': '2026-10-09T06:05:00Z',
          });
          return http.Response(
            'null',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(path, '/rest/v1/case_messages');
        final params = request.url.queryParameters;
        final key = params.containsKey('risk_report_id')
            ? 'risk_report_id'
            : 'ticket_id';
        return http.Response(
          jsonEncode(
            stored
                .where((row) => row[key] == params[key]!.substring(3))
                .toList(),
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: transport,
      );
      addTearDown(client.dispose);
      addTearDown(transport.close);
      final risks = SupabaseParticipantRiskReportQueryRepository(
        client: client,
      );
      final tickets = SupabaseParticipantSupportTicketRepository(
        client: client,
      );
      await risks.postMessage('risk-1', 'hello');
      expect((await risks.fetchMessages('risk-1')).single.body, 'hello');
      expect(await tickets.fetchMessages('ticket-1'), isEmpty);
    },
  );

  test(
    'participant conversations preserve their parent filter after consolidation',
    () async {
      final rows =
          [
                {
                  'id': 'ticket-message',
                  'ticket_id': 'ticket-1',
                  'risk_report_id': null,
                },
                {
                  'id': 'risk-message',
                  'ticket_id': null,
                  'risk_report_id': 'risk-1',
                },
              ]
              .map(
                (parent) => <String, dynamic>{
                  ...parent,
                  'sender_id': 'support-1',
                  'sender_role_snapshot': 'support',
                  'visibility': 'public',
                  'body': 'Reply',
                  'created_at': '2026-10-09T02:00:00Z',
                },
              )
              .toList();
      final transport = MockClient((request) async {
        expect(request.url.path, '/rest/v1/case_messages');
        final params = request.url.queryParameters;
        final key = params.containsKey('ticket_id')
            ? 'ticket_id'
            : 'risk_report_id';
        final parent = params[key]!.substring(3);
        return http.Response(
          jsonEncode(rows.where((row) => row[key] == parent).toList()),
          200,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: transport,
      );
      addTearDown(client.dispose);
      addTearDown(transport.close);
      final tickets = await SupabaseParticipantSupportTicketRepository(
        client: client,
      ).fetchMessages('ticket-1');
      final risks = await SupabaseParticipantRiskReportQueryRepository(
        client: client,
      ).fetchMessages('risk-1');
      expect(tickets.map((row) => row.id), ['ticket-message']);
      expect(risks.map((row) => row.id), ['risk-message']);
    },
  );
}
