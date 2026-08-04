import 'dart:convert';

import 'package:delivery_app/core/models/driver_order_cancellation_event.dart';
import 'package:delivery_app/core/services/customer_order_service.dart';
import 'package:delivery_app/core/services/notification_service.dart';
import 'package:delivery_app/core/services/realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'verified cancellation broadcasts and keeps assigned-driver notification',
    () async {
      final client = _cancellationClient(
        updatedOrder: {
          'order_id': 'order-1',
          'new_status': 'cancelled',
          'driver_id': 'driver-1',
          'tracking_code': '10001',
        },
      );
      addTearDown(client.dispose);
      final realtime = _RecordingRealtimeService(client);
      final notifications = _RecordingNotificationService(client);
      final service = CustomerOrderService(
        client: client,
        realtimeService: realtime,
        notificationService: notifications,
      );

      await service.cancelOrder('order-1', 'customer-1');

      expect(realtime.events, hasLength(1));
      expect(realtime.events.single.orderId, 'order-1');
      expect(realtime.events.single.driverId, 'driver-1');
      expect(realtime.events.single.orderCode, 'GH-10001');
      expect(notifications.cancelledOrderIds, ['order-1']);
    },
  );

  test('zero-row cancellation fails without broadcasting', () async {
    final client = _cancellationClient(updatedOrder: null);
    addTearDown(client.dispose);
    final realtime = _RecordingRealtimeService(client);
    final service = CustomerOrderService(
      client: client,
      realtimeService: realtime,
      notificationService: _RecordingNotificationService(client),
    );

    await expectLater(
      service.cancelOrder('order-1', 'customer-1'),
      throwsA(isA<Exception>()),
    );

    expect(realtime.events, isEmpty);
  });
}

SupabaseClient _cancellationClient({
  required Map<String, dynamic>? updatedOrder,
}) {
  final httpClient = MockClient((request) async {
    if (request.method == 'POST' &&
        request.url.path.endsWith('/rpc/cancel_customer_order')) {
      return http.Response(
        jsonEncode(updatedOrder == null ? [] : [updatedOrder]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }

    return http.Response('Not found', 404, request: request);
  });

  return SupabaseClient(
    'http://localhost:54321',
    'test-anon-key',
    httpClient: httpClient,
  );
}

class _RecordingRealtimeService extends RealtimeService {
  _RecordingRealtimeService(SupabaseClient client) : super(client: client);

  final List<DriverOrderCancellationEvent> events = [];

  @override
  Future<void> broadcastOrderCancelled(
    DriverOrderCancellationEvent event,
  ) async {
    events.add(event);
  }
}

class _RecordingNotificationService extends NotificationService {
  _RecordingNotificationService(SupabaseClient client) : super(client: client);

  final List<String> cancelledOrderIds = [];

  @override
  Future<void> notifyDriverOrderCancelled({
    required String driverUserId,
    required String orderId,
    required String orderCode,
  }) async {
    cancelledOrderIds.add(orderId);
  }
}
