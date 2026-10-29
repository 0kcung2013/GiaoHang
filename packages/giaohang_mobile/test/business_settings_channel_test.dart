import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_config/giaohang_config.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'settings and public contacts share one channel and refetch trusted API values on broadcast/resume',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final joined = Completer<WebSocket>();
      final rejoined = Completer<WebSocket>();
      var joins = 0;
      final sockets = <WebSocket>[];
      final serverSubscription = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        void reply(Map<String, dynamic> message) {
          try {
            socket.add(
              jsonEncode({
                'topic': message['topic'],
                'event': 'phx_reply',
                'ref': message['ref'],
                'payload': {'status': 'ok', 'response': {}},
              }),
            );
          } on StateError {
            // A peer may send leave and close before its reply is processed.
          }
        }

        socket.listen((raw) {
          if (socket.readyState != WebSocket.open) return;
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          if (message['event'] == 'phx_join') {
            joins++;
            reply(message);
            if (!joined.isCompleted) {
              joined.complete(socket);
            } else if (!rejoined.isCompleted) {
              rejoined.complete(socket);
            }
          } else if (message['event'] == 'phx_leave' ||
              message['event'] == 'heartbeat') {
            reply(message);
          }
        });
      });
      var revision = 1;
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
        httpClient: MockClient((request) async {
          final values = {
            'company_name': 'Company $revision',
            'support_email': 'help$revision@example.com',
            'support_phone': '0901234567',
          };
          final contact = request.url.path.endsWith('business-contact');
          return http.Response(
            jsonEncode(
              contact ? values : {'revision': revision, 'values': values},
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final source = BusinessSettingsLive(client);
      final settings2 = Completer<BusinessSettings>();
      final settings3 = Completer<BusinessSettings>();
      final settings4 = Completer<BusinessSettings>();
      final settled = Completer<void>();
      var initialFetches = 0;
      final contact2 = Completer<BusinessSettings>();
      final settingsSubscription = source.watch().listen((value) {
        if (value.revision == 1 &&
            ++initialFetches >= 2 &&
            !settled.isCompleted) {
          settled.complete();
        }
        if (value.revision == 2 && !settings2.isCompleted) {
          settings2.complete(value);
        }
        if (value.revision == 3 && !settings3.isCompleted) {
          settings3.complete(value);
        }
        if (value.revision == 4 && !settings4.isCompleted) {
          settings4.complete(value);
        }
      });
      final contactSubscription = source.watchContact().listen((value) {
        if (value.companyName == 'Company 2' && !contact2.isCompleted) {
          contact2.complete(value);
        }
      });
      try {
        final socket = await joined.future.timeout(const Duration(seconds: 5));
        await settled.future.timeout(const Duration(seconds: 5));
        expect(joins, 1);
        revision = 2;
        // Even a forged message cannot inject settings or choose the revision.
        socket.add(
          jsonEncode({
            'topic': 'realtime:business-settings',
            'event': 'broadcast',
            'payload': {
              'event': 'settings_changed',
              'payload': {
                'revision': 9999,
                'values': {'company_name': 'untrusted'},
              },
            },
          }),
        );
        expect(
          (await settings2.future.timeout(const Duration(seconds: 5))).revision,
          2,
        );
        expect(
          (await contact2.future.timeout(
            const Duration(seconds: 5),
          )).supportEmail,
          'help2@example.com',
        );
        revision = 3;
        source.refresh();
        expect(
          (await settings3.future.timeout(
            const Duration(seconds: 5),
          )).companyName,
          'Company 3',
        );
        expect(joins, 1);
        revision = 4;
        await socket.close();
        await rejoined.future.timeout(const Duration(seconds: 5));
        expect(
          (await settings4.future.timeout(const Duration(seconds: 5))).revision,
          4,
        );
        expect(joins, 2);
      } finally {
        await settingsSubscription.cancel();
        await contactSubscription.cancel();
        await client.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await serverSubscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
