import 'package:customer_app/core/models/driver_order_cancellation_event.dart';
import 'package:customer_app/core/models/order_model.dart';
import 'package:customer_app/core/providers/customer_providers.dart';
import 'package:customer_app/core/services/realtime_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'assigned cancellation publishes only for the matching driver',
    () async {
      final fixture = await _CancellationProviderFixture.create(
        availableOrders: [_order('order-1')],
      );
      addTearDown(fixture.dispose);

      fixture.realtime.emit(
        const DriverOrderCancellationEvent(
          eventId: 'cancel-order-1',
          orderId: 'order-1',
          driverId: 'driver-2',
          orderCode: 'GH-10001',
        ),
      );

      expect(
        fixture.container.read(driverOrderCancellationEventProvider),
        isNull,
      );

      fixture.realtime.emit(
        const DriverOrderCancellationEvent(
          eventId: 'cancel-order-1-matching',
          orderId: 'order-1',
          driverId: 'driver-1',
          orderCode: 'GH-10001',
        ),
      );

      expect(
        fixture.container.read(driverOrderCancellationEventProvider)?.eventId,
        'cancel-order-1-matching',
      );
    },
  );

  test(
    'unassigned cancellation uses local availability and invalidates streams',
    () async {
      final fixture = await _CancellationProviderFixture.create(
        availableOrders: [_order('order-2')],
      );
      addTearDown(fixture.dispose);
      var localEventCount = 0;
      final subscription = fixture.container.listen(
        driverOrderCancellationEventProvider,
        (previous, next) {
          if (next != null) localEventCount++;
        },
      );
      addTearDown(subscription.close);

      const event = DriverOrderCancellationEvent(
        eventId: 'cancel-order-2',
        orderId: 'order-2',
        orderCode: 'GH-10002',
      );
      fixture.realtime.emit(event);

      expect(
        fixture.container.read(driverOrderCancellationEventProvider)?.orderId,
        'order-2',
      );
      expect(localEventCount, 1);
      await fixture.reloadOrderStreams();
      expect(fixture.availableBuildCount, 2);
      expect(fixture.assignedBuildCount, 2);

      fixture.realtime.emit(event);
      await fixture.reloadOrderStreams();
      expect(localEventCount, 1);
      expect(fixture.availableBuildCount, 2);
      expect(fixture.assignedBuildCount, 2);
    },
  );

  test(
    'unassigned cancellation stays silent when not locally available',
    () async {
      final fixture = await _CancellationProviderFixture.create(
        availableOrders: [_order('order-3')],
      );
      addTearDown(fixture.dispose);

      fixture.realtime.emit(
        const DriverOrderCancellationEvent(
          eventId: 'cancel-order-4',
          orderId: 'order-4',
          orderCode: 'GH-10004',
        ),
      );

      expect(
        fixture.container.read(driverOrderCancellationEventProvider),
        isNull,
      );
    },
  );
}

class _CancellationProviderFixture {
  _CancellationProviderFixture._(
    this.container,
    this.realtime,
    this.client,
    this._availableBuilds,
    this._assignedBuilds,
  );

  static Future<_CancellationProviderFixture> create({
    required List<OrderModel> availableOrders,
  }) async {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    final realtime = _FakeRealtimeService(client);
    final availableBuilds = _BuildCounter();
    final assignedBuilds = _BuildCounter();
    final container = ProviderContainer(
      overrides: [
        realtimeServiceProvider.overrideWithValue(realtime),
        availableOrdersProvider.overrideWith((ref, driverId) {
          availableBuilds.value++;
          return Stream.value(availableOrders);
        }),
        driverOrdersProvider.overrideWith((ref, driverId) {
          assignedBuilds.value++;
          return Stream.value(const <OrderModel>[]);
        }),
      ],
    );

    await container.read(availableOrdersProvider('driver-1').future);
    await container.read(driverOrdersProvider('driver-1').future);
    await container.read(
      driverCancelledOrderRealtimeProvider('driver-1').future,
    );

    return _CancellationProviderFixture._(
      container,
      realtime,
      client,
      availableBuilds,
      assignedBuilds,
    );
  }

  final ProviderContainer container;
  final _FakeRealtimeService realtime;
  final SupabaseClient client;
  final _BuildCounter _availableBuilds;
  final _BuildCounter _assignedBuilds;

  int get availableBuildCount => _availableBuilds.value;
  int get assignedBuildCount => _assignedBuilds.value;

  Future<void> reloadOrderStreams() async {
    await container.read(availableOrdersProvider('driver-1').future);
    await container.read(driverOrdersProvider('driver-1').future);
  }

  void dispose() {
    container.dispose();
    client.dispose();
  }
}

class _BuildCounter {
  int value = 0;
}

class _FakeRealtimeService extends RealtimeService {
  _FakeRealtimeService(this.client) : super(client: client);

  final SupabaseClient client;
  void Function(DriverOrderCancellationEvent event)? _onCancelled;

  @override
  RealtimeChannel subscribeToDriverOrderCancellations(
    void Function(DriverOrderCancellationEvent event) onCancelled,
  ) {
    _onCancelled = onCancelled;
    return client.channel('fake-driver-order-events');
  }

  void emit(DriverOrderCancellationEvent event) {
    _onCancelled?.call(event);
  }
}

OrderModel _order(String id) {
  final now = DateTime.utc(2026, 7, 30);
  return OrderModel(
    id: id,
    customerId: 'customer-1',
    status: 'pending',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10,
    pickupLng: 106,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.1,
    deliveryLng: 106.1,
    createdAt: now,
    trackingCode: id,
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
