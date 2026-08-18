import 'dart:async';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/services/driver_order_offer_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns only live persisted offers owned by the signed-in driver', () {
    final now = DateTime.utc(2026, 8, 14, 8);
    final orders = [
      _order(
        id: 'matching',
        createdAt: now,
        offeredDriverId: 'driver-1',
        offerExpiresAt: now.add(const Duration(seconds: 30)),
      ),
      _order(
        id: 'other-driver',
        createdAt: now,
        offeredDriverId: 'driver-2',
        offerExpiresAt: now.add(const Duration(seconds: 30)),
      ),
      _order(
        id: 'expired',
        createdAt: now,
        offeredDriverId: 'driver-1',
        offerExpiresAt: now,
      ),
    ];

    final visible = filterPersistedDriverOffers(
      orders,
      driverUserId: 'driver-1',
      now: now,
    );

    expect(visible.map((order) => order.id), ['matching']);
  });

  test('does not expose server offers when the driver id is missing', () {
    final now = DateTime.utc(2026, 8, 14, 8);

    final visible = filterPersistedDriverOffers(
      [
        _order(
          id: 'matching',
          createdAt: now,
          offeredDriverId: 'driver-1',
          offerExpiresAt: now.add(const Duration(seconds: 30)),
        ),
      ],
      driverUserId: '',
      now: now,
    );

    expect(visible, isEmpty);
  });

  test(
    'removes a cached realtime row exactly when its offer expires',
    () async {
      final startedAt = DateTime.utc(2026, 8, 14, 8);
      var currentTime = startedAt;
      Duration? scheduledDelay;
      void Function()? scheduledCallback;
      final source = StreamController<List<OrderModel>>(sync: true);
      final snapshots = <List<OrderModel>>[];
      final subscription = watchPersistedDriverOffers(
        source.stream,
        driverUserId: 'driver-1',
        now: () => currentTime,
        scheduleExpiry: (delay, callback) {
          scheduledDelay = delay;
          scheduledCallback = callback;
          return () {
            if (identical(scheduledCallback, callback)) {
              scheduledCallback = null;
            }
          };
        },
      ).listen(snapshots.add);

      source.add([
        _order(
          id: 'cached-offer',
          createdAt: startedAt,
          offeredDriverId: 'driver-1',
          offerExpiresAt: startedAt.add(const Duration(seconds: 45)),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.last.map((order) => order.id), ['cached-offer']);
      expect(scheduledDelay, const Duration(seconds: 45));

      currentTime = startedAt.add(const Duration(seconds: 45));
      scheduledCallback?.call();
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.last, isEmpty);

      await subscription.cancel();
      await source.close();
    },
  );
}

OrderModel _order({
  required String id,
  required DateTime createdAt,
  required String offeredDriverId,
  required DateTime offerExpiresAt,
}) {
  return OrderModel(
    id: id,
    customerId: 'customer-1',
    status: 'pending',
    pickupAddress: 'Pickup',
    pickupLat: 10.7,
    pickupLng: 106.6,
    deliveryAddress: 'Delivery',
    deliveryLat: 10.8,
    deliveryLng: 106.7,
    createdAt: createdAt,
    trackingCode: 'GH-00001',
    assignmentExpiresAt: createdAt.add(const Duration(minutes: 15)),
    offeredDriverId: offeredDriverId,
    offerExpiresAt: offerExpiresAt,
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: createdAt,
  );
}
