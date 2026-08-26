import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/services/nearest_driver_service.dart';

void main() {
  test(
    'does not mutate orders from the client when assignment RPC fails',
    () async {
      final requests = <http.Request>[];
      final now = DateTime.now().toUtc();
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith(
          '/rest/v1/rpc/assign_order_to_nearest_driver',
        )) {
          return http.Response(
            '{"message":"rpc unavailable"}',
            500,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith(
          '/functions/v1/find-nearest-drivers-redis',
        )) {
          return http.Response('{}', 500);
        }
        if (request.url.path.endsWith('/rest/v1/rpc/find_nearest_drivers')) {
          return http.Response(
            '[{"user_id":"driver-1","current_lat":10.0,'
            '"current_lng":106.0,"distance_meters":100,'
            '"rating":5,"location_updated_at":"${now.toIso8601String()}"}]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '[{"id":"order-1"}]',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: httpClient,
      );
      addTearDown(client.dispose);
      final service = NearestDriverService(client: client, now: () => now);

      await expectLater(
        () => service.assignNearestDriver(
          orderId: 'order-1',
          pickupLat: 10,
          pickupLng: 106,
        ),
        throwsA(isA<DriverAssignmentException>()),
      );
      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        ['POST /rest/v1/rpc/assign_order_to_nearest_driver'],
      );
    },
  );

  test('uses a two kilometer default assignment radius', () async {
    late http.Request rpcRequest;
    final httpClient = MockClient((request) async {
      rpcRequest = request;
      return http.Response(
        '"driver-1"',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      httpClient: httpClient,
    );
    addTearDown(client.dispose);
    final service = NearestDriverService(client: client);

    await expectLater(
      () => service.assignNearestDriver(
        orderId: 'order-radius',
        pickupLat: 10,
        pickupLng: 106,
      ),
      throwsA(isA<DriverAssignmentException>()),
    );

    final params = jsonDecode(rpcRequest.body) as Map<String, dynamic>;
    expect(params['p_radius_meters'], 2000);
  });

  test('prefers the nearer driver regardless of rating', () async {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    addTearDown(client.dispose);
    final service = NearestDriverService(
      client: client,
      now: () => DateTime.utc(2026, 8, 3, 10, 1),
      assignableDriverLoader:
          ({required double nearLat, required double nearLng}) async {
            return [
              AssignableDriverPoint(
                userId: 'driver-nearest',
                lat: 10,
                lng: 106,
                distanceMeters: 100,
                rating: 4.5,
                locationUpdatedAt: DateTime.utc(2026, 8, 3, 10),
              ),
              AssignableDriverPoint(
                userId: 'driver-better-rated',
                lat: 10.001,
                lng: 106.001,
                distanceMeters: 180,
                rating: 4.9,
                locationUpdatedAt: DateTime.utc(2026, 8, 3, 9, 59),
              ),
            ];
          },
    );

    final allocations = await service.allocateOrderOffers([
      _order(id: 'order-rating', createdAt: DateTime.utc(2026, 8, 3, 9)),
    ]);

    expect(allocations['order-rating'], 'driver-nearest');
  });

  test('prefers the nearest driver across the candidate pool', () async {
    final now = DateTime.utc(2026, 8, 3, 10, 1);
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    addTearDown(client.dispose);
    final service = NearestDriverService(
      client: client,
      now: () => now,
      assignableDriverLoader:
          ({required double nearLat, required double nearLng}) async {
            return [
              AssignableDriverPoint(
                userId: 'driver-nearest',
                lat: 10,
                lng: 106,
                distanceMeters: 100,
                rating: 4,
                locationUpdatedAt: now,
              ),
              AssignableDriverPoint(
                userId: 'driver-outside-cohort',
                lat: 10.002,
                lng: 106.002,
                distanceMeters: 201,
                rating: 5,
                locationUpdatedAt: now,
              ),
            ];
          },
    );

    final allocations = await service.allocateOrderOffers([
      _order(id: 'order-cohort', createdAt: now),
    ]);

    expect(allocations['order-cohort'], 'driver-nearest');
  });

  test('does not let GPS freshness override a nearer driver', () async {
    final now = DateTime.utc(2026, 8, 3, 10, 1);
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    addTearDown(client.dispose);
    final service = NearestDriverService(
      client: client,
      now: () => now,
      assignableDriverLoader:
          ({required double nearLat, required double nearLng}) async {
            return [
              AssignableDriverPoint(
                userId: 'driver-older-gps',
                lat: 10,
                lng: 106,
                distanceMeters: 100,
                rating: 4.8,
                locationUpdatedAt: now.subtract(const Duration(minutes: 2)),
              ),
              AssignableDriverPoint(
                userId: 'driver-fresher-gps',
                lat: 10.001,
                lng: 106.001,
                distanceMeters: 150,
                rating: 4.8,
                locationUpdatedAt: now.subtract(const Duration(seconds: 30)),
              ),
            ];
          },
    );

    final allocations = await service.allocateOrderOffers([
      _order(id: 'order-tie-break', createdAt: now),
    ]);

    expect(allocations['order-tie-break'], 'driver-older-gps');
  });

  test('excludes a driver whose GPS is older than three minutes', () async {
    final now = DateTime.now().toUtc();
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    addTearDown(client.dispose);
    final service = NearestDriverService(
      client: client,
      now: () => now,
      assignableDriverLoader:
          ({required double nearLat, required double nearLng}) async {
            return [
              AssignableDriverPoint(
                userId: 'driver-stale',
                lat: 10,
                lng: 106,
                distanceMeters: 100,
                rating: 5,
                locationUpdatedAt: now.subtract(const Duration(minutes: 4)),
              ),
              AssignableDriverPoint(
                userId: 'driver-fresh',
                lat: 10.001,
                lng: 106.001,
                distanceMeters: 150,
                rating: 4,
                locationUpdatedAt: now.subtract(const Duration(minutes: 1)),
              ),
            ];
          },
    );

    final allocations = await service.allocateOrderOffers([
      _order(id: 'order-freshness', createdAt: now),
    ]);

    expect(allocations['order-freshness'], 'driver-fresh');
  });

  test(
    're-ranks remaining drivers after transfers until the round is exhausted',
    () async {
      final now = DateTime.utc(2026, 8, 4, 10);
      final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
      addTearDown(client.dispose);
      final service = NearestDriverService(
        client: client,
        now: () => now,
        assignableDriverLoader:
            ({required double nearLat, required double nearLng}) async => [
              AssignableDriverPoint(
                userId: 'driver-3',
                lat: 10,
                lng: 106,
                distanceMeters: 300,
                rating: 4.8,
                locationUpdatedAt: now,
              ),
              AssignableDriverPoint(
                userId: 'driver-2',
                lat: 10.01,
                lng: 106.01,
                distanceMeters: 1300,
                rating: 4.8,
                locationUpdatedAt: now,
              ),
              AssignableDriverPoint(
                userId: 'driver-1',
                lat: 10.04,
                lng: 106.04,
                distanceMeters: 4300,
                rating: 4.8,
                locationUpdatedAt: now,
              ),
            ],
      );
      final order = _order(id: 'order-transfer-chain', createdAt: now);

      Future<String?> offeredDriverFor(OrderModel currentOrder) async {
        final allocations = await service.allocateOrderOffers([currentOrder]);
        return allocations[currentOrder.id];
      }

      expect(await offeredDriverFor(order), 'driver-3');

      final afterDriver3Transfers = order.copyWith(
        rejectedBy: const ['driver-3'],
      );
      expect(await offeredDriverFor(afterDriver3Transfers), 'driver-2');

      final afterDriver2Transfers = order.copyWith(
        rejectedBy: const ['driver-3', 'driver-2'],
      );
      expect(await offeredDriverFor(afterDriver2Transfers), 'driver-1');

      final exhaustedRound = order.copyWith(
        rejectedBy: const ['driver-3', 'driver-2', 'driver-1'],
      );
      expect(await offeredDriverFor(exhaustedRound), isNull);
    },
  );

  test('distributes two pending orders to two different drivers', () async {
    final now = DateTime.utc(2026, 7, 29, 8, 2);
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    addTearDown(client.dispose);
    final service = NearestDriverService(
      client: client,
      now: () => now,
      assignableDriverLoader:
          ({required double nearLat, required double nearLng}) async {
            return [
              AssignableDriverPoint(
                userId: 'driver-1',
                lat: 10.0,
                lng: 106.0,
                distanceMeters: 100,
                locationUpdatedAt: now,
              ),
              AssignableDriverPoint(
                userId: 'driver-2',
                lat: 10.01,
                lng: 106.01,
                distanceMeters: 200,
                locationUpdatedAt: now,
              ),
            ];
          },
    );
    final firstOrder = _order(
      id: 'order-1',
      createdAt: DateTime.utc(2026, 7, 29, 8),
    );
    final secondOrder = _order(
      id: 'order-2',
      createdAt: DateTime.utc(2026, 7, 29, 8, 1),
    );
    final newestFirst = [secondOrder, firstOrder];

    final driverOneOrders = await service.filterOrdersForNearestDriver(
      newestFirst,
      'driver-1',
    );
    final driverTwoOrders = await service.filterOrdersForNearestDriver(
      newestFirst,
      'driver-2',
    );

    expect(driverOneOrders.map((order) => order.id), ['order-1']);
    expect(driverTwoOrders.map((order) => order.id), ['order-2']);
  });
}

OrderModel _order({required String id, required DateTime createdAt}) {
  return OrderModel(
    id: id,
    customerId: 'customer-1',
    status: 'pending',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.0,
    pickupLng: 106.0,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.02,
    deliveryLng: 106.02,
    createdAt: createdAt,
    trackingCode: id,
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: createdAt,
  );
}
