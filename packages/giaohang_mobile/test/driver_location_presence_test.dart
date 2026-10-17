import 'dart:convert';

import 'package:giaohang_mobile/core/services/driver_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'OFF calls the server presence endpoint instead of a separate RPC',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          expect(request.url.path, '/functions/v1/driver-location-presence');
          expect(jsonDecode(request.body), {'event': 'offline'});
          return http.Response(
            jsonEncode({
              'ok': true,
              'is_available': false,
              'cache_synced': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final service = DriverService(
        client: client,
        locationPublisher:
            ({
              required driverProfileId,
              required lat,
              required lng,
              heading,
              speed,
            }) async {},
      );
      await service.updateAvailability(false);
      expect(requests, hasLength(1));
    },
  );

  test(
    'a transient Redis outage does not report a committed OFF as failed',
    () async {
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'ok': true,
              'is_available': false,
              'cache_synced': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      final service = DriverService(
        client: client,
        locationPublisher:
            ({
              required driverProfileId,
              required lat,
              required lng,
              heading,
              speed,
            }) async {},
      );
      await service.updateAvailability(false);
    },
  );

  test('a failed OFF command is surfaced to the caller', () async {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    addTearDown(client.dispose);
    final service = DriverService(
      client: client,
      presenceInvoker: (_) async => throw Exception('OFF rejected'),
      rpcInvoker: (_, _) async => throw Exception('OFF RPC also rejected'),
      locationPublisher:
          ({
            required driverProfileId,
            required lat,
            required lng,
            heading,
            speed,
          }) async {},
    );
    await expectLater(
      service.updateAvailability(false),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'OFF remains usable through the existing RPC during an Edge outage',
    () async {
      final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
      addTearDown(client.dispose);
      final service = DriverService(
        client: client,
        presenceInvoker: (_) async => throw Exception('Edge unavailable'),
        rpcInvoker: (name, params) async {
          expect(name, 'set_driver_availability');
          expect(params, {'p_is_available': false});
          return false;
        },
        locationPublisher:
            ({
              required driverProfileId,
              required lat,
              required lng,
              heading,
              speed,
            }) async {},
      );
      await service.updateAvailability(false);
    },
  );

  test(
    'Online cache notification failure preserves a successful PIN command',
    () async {
      final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
      addTearDown(client.dispose);
      final service = DriverService(
        client: client,
        presenceInvoker: (_) async =>
            throw Exception('Redis notification unavailable'),
        rpcInvoker: (_, _) async => {
          'status': 'online',
          'offered_order_id': 'order-1',
        },
        locationPublisher:
            ({
              required driverProfileId,
              required lat,
              required lng,
              heading,
              speed,
            }) async {},
      );
      expect(
        await service.setOnlineWithLocation(
          driverProfileId: 'profile-1',
          lat: 10.8,
          lng: 106.7,
          pin: '123456',
        ),
        'order-1',
      );
    },
  );
}
