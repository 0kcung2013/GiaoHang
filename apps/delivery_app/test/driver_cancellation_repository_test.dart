import 'package:delivery_app/features/driver/cancellation/data/driver_cancellation_repository.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_strings.dart';
import 'package:delivery_app/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:delivery_app/features/driver/cancellation/models/driver_cancellation_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  final serverNow = DateTime.utc(2026, 9, 27, 10);
  final deadline = serverNow.add(const Duration(minutes: 30));

  test('cooldown uses server time even when the device clock differs', () {
    final state = DriverAcceptanceState.fromJson({
      'server_now': serverNow.toIso8601String(),
      'locked_until': deadline.toIso8601String(),
    });
    expect(state.isLocked, isTrue);
    expect(state.now().difference(serverNow).inSeconds, 0);
    expect(
      DriverAcceptanceState(
        serverNow: deadline,
        lockedUntil: deadline,
      ).isLocked,
      isFalse,
    );
  });

  test(
    'personal cancellation sends the reason and reads committed deadline',
    () async {
      final repository = DriverCancellationRepository(
        invoke: (name, params) async {
          expect(name, 'cancel_driver_order');
          expect(params, {'p_order_id': 'order-1', 'p_reason': 'personal'});
          return {
            'order_id': 'order-1',
            'new_status': 'pending',
            'server_now': serverNow.toIso8601String(),
            'locked_until': deadline.toIso8601String(),
          };
        },
      );
      final state = await repository.cancel(
        'order-1',
        DriverCancellationReason.personal,
      );
      expect(state.lockedUntil, deadline);
      expect(state.isLocked, isTrue);
    },
  );

  test('store cancellation has no acceptance lock', () async {
    final repository = DriverCancellationRepository(
      invoke: (name, params) async {
        expect(params['p_reason'], 'store_closed');
        return {
          'order_id': 'order-1',
          'new_status': 'cancelled',
          'server_now': serverNow.toIso8601String(),
          'locked_until': null,
        };
      },
    );
    expect(
      (await repository.cancel(
        'order-1',
        DriverCancellationReason.storeClosed,
      )).isLocked,
      isFalse,
    );
  });

  test('fresh snapshot protects orders with pickup custody', () async {
    final repository = DriverCancellationRepository(
      invoke: (name, params) async {
        expect(name, 'get_driver_order_cancellation_state');
        return {
          'status': 'picking_up',
          'pickup_confirmed': true,
          'pickup_arrived_at': serverNow.toIso8601String(),
          'server_now': deadline.toIso8601String(),
        };
      },
    );
    final snapshot = await repository.getCancellationState('order-1');
    expect(snapshot.policy.canCancel, isFalse);
    expect(snapshot.clock.now().difference(deadline).inSeconds, 0);
  });

  test('arrival reads the persisted first-arrival timestamp', () async {
    final repository = DriverCancellationRepository(
      invoke: (name, params) async {
        expect(name, 'confirm_driver_pickup_arrival');
        expect(params, {
          'p_order_id': 'order-1',
          'p_lat': 10.8,
          'p_lng': 106.7,
        });
        return {'pickup_arrived_at': serverNow.toIso8601String()};
      },
    );
    expect(
      await repository.confirmArrival(
        orderId: 'order-1',
        latitude: 10.8,
        longitude: 106.7,
      ),
      serverNow,
    );
  });

  test('server wait and custody errors are meaningful in the sheet', () async {
    for (final entry in {
      'STORE_CANCELLATION_WAIT_REQUIRED': DriverCancellationStrings.storeWait,
      'ORDER_ALREADY_PICKED_UP': DriverCancellationStrings.unavailable,
    }.entries) {
      final repository = DriverCancellationRepository(
        invoke: (_, _) async => throw Exception(entry.key),
      );
      await expectLater(
        repository.cancel('order-1', DriverCancellationReason.personal),
        throwsA(
          isA<DriverCancellationException>().having(
            (e) => e.message,
            'message',
            entry.value,
          ),
        ),
      );
    }
  });

  test('a response for another order is never treated as success', () async {
    final repository = DriverCancellationRepository(
      invoke: (_, _) async => {
        'order_id': 'other-order',
        'new_status': 'pending',
        'server_now': serverNow.toIso8601String(),
      },
    );
    await expectLater(
      repository.cancel('order-1', DriverCancellationReason.personal),
      throwsA(isA<DriverCancellationException>()),
    );
  });

  test('shared driver model preserves the lock timestamp when copied', () {
    final driver = DriverModel.fromJson({
      'id': 'profile',
      'user_id': 'driver',
      'acceptance_locked_until': deadline.toIso8601String(),
    });
    expect(driver.copyWith(isAvailable: true).acceptanceLockedUntil, deadline);
    expect(
      driver.toJson()['acceptance_locked_until'],
      deadline.toIso8601String(),
    );
  });
}
