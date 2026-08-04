import 'package:delivery_app/core/models/driver_order_cancellation_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverOrderCancellationEvent payload contract', () {
    test('parses and serializes a complete cancellation event', () {
      final event = DriverOrderCancellationEvent.fromBroadcastPayload({
        'eventId': 'cancel-order-1-123',
        'orderId': 'order-1',
        'driverId': 'driver-1',
        'orderCode': 'GH-10001',
      });

      expect(event, isNotNull);
      expect(event!.eventId, 'cancel-order-1-123');
      expect(event.orderId, 'order-1');
      expect(event.driverId, 'driver-1');
      expect(event.orderCode, 'GH-10001');
      expect(event.toBroadcastPayload(), {
        'eventId': 'cancel-order-1-123',
        'orderId': 'order-1',
        'driverId': 'driver-1',
        'orderCode': 'GH-10001',
      });
    });

    test('rejects a payload without a usable event or order ID', () {
      expect(
        DriverOrderCancellationEvent.fromBroadcastPayload({
          'eventId': '',
          'orderId': 'order-1',
          'orderCode': 'GH-10001',
        }),
        isNull,
      );
      expect(
        DriverOrderCancellationEvent.fromBroadcastPayload({
          'eventId': 'cancel-order-1-123',
          'orderId': '   ',
          'orderCode': 'GH-10001',
        }),
        isNull,
      );
    });
  });

  group('DriverOrderCancellationEvent relevance', () {
    test('assigned cancellation is relevant only to its assigned driver', () {
      const event = DriverOrderCancellationEvent(
        eventId: 'cancel-order-1-123',
        orderId: 'order-1',
        driverId: 'driver-1',
        orderCode: 'GH-10001',
      );

      expect(
        event.isRelevantTo(
          driverUserId: 'driver-1',
          availableOrderIds: const {},
        ),
        isTrue,
      );
      expect(
        event.isRelevantTo(
          driverUserId: 'driver-2',
          availableOrderIds: const {'order-1'},
        ),
        isFalse,
      );
    });

    test('unassigned cancellation is relevant only when locally available', () {
      const event = DriverOrderCancellationEvent(
        eventId: 'cancel-order-2-123',
        orderId: 'order-2',
        orderCode: 'GH-10002',
      );

      expect(
        event.isRelevantTo(
          driverUserId: 'driver-1',
          availableOrderIds: const {'order-2'},
        ),
        isTrue,
      );
      expect(
        event.isRelevantTo(
          driverUserId: 'driver-1',
          availableOrderIds: const {'order-3'},
        ),
        isFalse,
      );
    });
  });
}
