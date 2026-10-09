import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/risk_reports/data/risk_report_repository.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final count in [14, 451]) {
    for (final risk in [true, false]) {
      test(
        '${risk ? 'risk' : 'ticket'} repository reads $count unique cases',
        () async {
          final source = List.generate(
            count,
            (index) => <String, dynamic>{
              'id': index.toString().padLeft(4, '0'),
              'status': index == count - 1 ? 'open' : 'resolved',
              'category': 'contact_issue',
              'title': 'Không liên lạc được',
              'subject': 'Không liên lạc được',
              'created_at': '2026-10-08T01:26:07Z',
              'updated_at': '2026-10-08T01:26:07Z',
            },
          );
          final requests = <Uri>[];
          final httpClient = MockClient((request) async {
            requests.add(request.url);
            final params = request.url.queryParameters;
            final cursor = params['id']?.substring(3);
            final rows = source
                .where(
                  (row) =>
                      cursor == null ||
                      (row['id'] as String).compareTo(cursor) > 0,
                )
                .toList();
            if (params['order']!.startsWith('id.desc')) {
              rows.sort(
                (a, b) => (b['id'] as String).compareTo(a['id'] as String),
              );
            }
            return http.Response(
              jsonEncode(rows.take(int.parse(params['limit']!)).toList()),
              200,
              request: request,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          });
          final client = SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            httpClient: httpClient,
          );
          addTearDown(client.dispose);
          addTearDown(httpClient.close);

          final ids = risk
              ? (await SupabaseRiskReportRepository(
                  client,
                ).fetchReports()).map((row) => row.id).toList()
              : (await SupabaseSupportTicketRepository(
                  client,
                ).fetchTickets()).map((row) => row.id).toList();

          expect(ids, hasLength(count));
          expect(ids, source.map((row) => row['id']).toList());
          expect(requests, hasLength((count / 200).ceil() + 1));
          expect(
            requests.every(
              (uri) => uri.queryParameters['order']!.startsWith('id.asc'),
            ),
            isTrue,
          );
        },
      );
    }
  }
}
