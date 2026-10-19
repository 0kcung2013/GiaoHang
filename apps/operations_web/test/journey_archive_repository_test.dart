import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:operations_web/features/support_monitoring/data/journey_archive_repository.dart';

void main() {
  test(
    'merges archive pages including empty page and fetches only archived IDs',
    () async {
      final cursors = <Object?>[];
      final storage = R2MediaClient(
        accessTokenProvider: () => 'jwt',
        gatewayBaseUrl: 'https://gateway.test',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/gps/archives');
          expect(request.headers['authorization'], 'Bearer jwt');
          cursors.add(jsonDecode(request.body)['cursor']);
          final page = cursors.length;
          return http.Response(
            jsonEncode({
              'archives': page == 2
                  ? []
                  : [
                      {
                        'orderId': 'order-1',
                        'firstDay': page == 1 ? '2026-10-14' : '2026-10-15',
                        'lastDay': page == 1 ? '2026-10-14' : '2026-10-16',
                        'chunks': 2,
                      },
                    ],
              'nextCursor': page < 3 ? 'cursor-$page' : null,
            }),
            200,
          );
        }),
      );
      final client = SupabaseClient(
        'https://supabase.test',
        'anon',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/orders');
          expect(request.url.queryParameters['id'], 'in.("order-1")');
          return http.Response(
            jsonEncode([
              {
                'id': 'order-1',
                'tracking_code': 'GH-123',
                'status': 'delivered',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final orders = await R2JourneyArchiveRepository(
        client: client,
        storage: storage,
      ).fetchArchives();
      expect(cursors, [null, 'cursor-1', 'cursor-2']);
      expect(orders.single.archive.chunks, 4);
      expect(orders.single.archive.firstDay, DateTime.utc(2026, 10, 14));
      expect(orders.single.archive.lastDay, DateTime.utc(2026, 10, 16));
    },
  );

  test('repeated archive cursor fails instead of looping', () async {
    final client = SupabaseClient('https://supabase.test', 'anon');
    addTearDown(client.dispose);
    final storage = R2MediaClient(
      accessTokenProvider: () => 'jwt',
      gatewayBaseUrl: 'https://gateway.test',
      httpClient: MockClient(
        (_) async => http.Response('{"archives":[],"nextCursor":"same"}', 200),
      ),
    );
    await expectLater(
      R2JourneyArchiveRepository(
        client: client,
        storage: storage,
      ).fetchArchives(),
      throwsStateError,
    );
  });
}
