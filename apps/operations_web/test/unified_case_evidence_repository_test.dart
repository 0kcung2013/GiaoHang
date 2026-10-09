import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/risk_reports/data/risk_report_repository.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late MockClient transport;
  const timestamp = '2026-10-09T02:00:00Z';
  final messages =
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
              'body': 'Public reply',
              'created_at': timestamp,
            },
          )
          .toList();
  final evidence = <Map<String, dynamic>>[
    {
      'id': 'location-evidence',
      'risk_report_id': 'risk-1',
      'order_id': 'order-1',
      'evidence_type': 'location',
      'latitude': 11.01,
      'longitude': 106.01,
      'captured_at': timestamp,
      'created_at': timestamp,
    },
    {
      'id': 'message-evidence',
      'risk_report_id': 'risk-1',
      'order_id': 'order-1',
      'evidence_type': 'message',
      'source_message_id': null,
      'sender_id': 'customer-1',
      'message_type': 'text',
      'body_snapshot': 'Preserved order conversation',
      'sent_at_snapshot': timestamp,
      'added_by': 'support-1',
      'created_at': timestamp,
    },
  ];

  setUp(() {
    transport = MockClient((request) async {
      final params = request.url.queryParameters;
      Iterable<Map<String, dynamic>> rows;
      if (request.url.path == '/rest/v1/case_messages') {
        rows = messages;
      } else if (request.url.path == '/rest/v1/risk_report_evidence') {
        rows = evidence;
      } else {
        fail('Unexpected retired table: ${request.url.path}');
      }
      for (final key in ['ticket_id', 'risk_report_id', 'evidence_type']) {
        final filter = params[key];
        if (filter?.startsWith('eq.') ?? false) {
          rows = rows.where((row) => row[key] == filter!.substring(3));
        } else if (filter?.startsWith('in.(') ?? false) {
          final allowed = filter!
              .substring(4, filter.length - 1)
              .split(',')
              .map((value) => value.replaceAll('"', ''));
          rows = rows.where((row) => allowed.contains(row[key]));
        }
      }
      return http.Response(
        jsonEncode(rows.toList()),
        200,
        request: request,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: transport,
    );
  });
  tearDown(() async {
    await client.dispose();
    transport.close();
  });

  test('ticket and risk conversations remain separate in one table', () async {
    final tickets = await SupabaseSupportTicketRepository(
      client,
    ).fetchMessages('ticket-1');
    final risks = await SupabaseRiskReportRepository(
      client,
    ).fetchCaseMessages('risk-1');
    expect(tickets.map((row) => row.id), ['ticket-message']);
    expect(risks.map((row) => row.id), ['risk-message']);
  });

  test(
    'attachment loader excludes message snapshots from the unified evidence',
    () async {
      final attachments = await SupabaseRiskReportRepository(
        client,
      ).fetchAttachments('risk-1');
      expect(attachments.map((row) => row.attachment.id), [
        'location-evidence',
      ]);
      expect(attachments.single.attachment.latitude, 11.01);
    },
  );

  test(
    'message loader retains a detached snapshot and excludes location rows',
    () async {
      final snapshots = await SupabaseRiskReportRepository(
        client,
      ).fetchMessageEvidence('risk-1');
      expect(snapshots.map((row) => row.id), ['message-evidence']);
      expect(snapshots.single.sourceMessageId, isNull);
      expect(snapshots.single.body, 'Preserved order conversation');
    },
  );
}
