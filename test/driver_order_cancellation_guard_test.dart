import 'package:customer_app/core/models/driver_order_cancellation_event.dart';
import 'package:customer_app/core/providers/customer_providers.dart';
import 'package:customer_app/features/driver/screens/navigation/widgets/driver_order_cancellation_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('matching cancellation calls cleanup and closes navigation', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var cleanupCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DriverOrderCancellationGuard(
                        orderId: 'order-1',
                        onCancelled: () {
                          cleanupCount++;
                        },
                        child: const Scaffold(body: Text('Điều hướng order-1')),
                      ),
                    ),
                  );
                },
                child: const Text('Mở điều hướng'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở điều hướng'));
    await tester.pumpAndSettle();

    container
        .read(driverOrderCancellationEventProvider.notifier)
        .state = const DriverOrderCancellationEvent(
      eventId: 'cancel-order-1',
      orderId: 'order-1',
      orderCode: 'GH-10001',
    );
    await tester.pumpAndSettle();

    expect(cleanupCount, 1);
    expect(find.text('Điều hướng order-1'), findsNothing);
    expect(find.text('Mở điều hướng'), findsOneWidget);
  });

  testWidgets('different order cancellation keeps navigation open', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var cleanupCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DriverOrderCancellationGuard(
            orderId: 'order-1',
            onCancelled: () {
              cleanupCount++;
            },
            child: const Scaffold(body: Text('Điều hướng order-1')),
          ),
        ),
      ),
    );

    container
        .read(driverOrderCancellationEventProvider.notifier)
        .state = const DriverOrderCancellationEvent(
      eventId: 'cancel-order-2',
      orderId: 'order-2',
      orderCode: 'GH-10002',
    );
    await tester.pump();

    expect(cleanupCount, 0);
    expect(find.text('Điều hướng order-1'), findsOneWidget);
  });

  testWidgets('duplicate event ID is handled only once', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var cleanupCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DriverOrderCancellationGuard(
            orderId: 'order-1',
            onCancelled: () {
              cleanupCount++;
            },
            child: const Scaffold(body: Text('Điều hướng order-1')),
          ),
        ),
      ),
    );

    container
        .read(driverOrderCancellationEventProvider.notifier)
        .state = const DriverOrderCancellationEvent(
      eventId: 'cancel-order-1',
      orderId: 'order-1',
      orderCode: 'GH-10001',
    );
    await tester.pump();
    container
        .read(driverOrderCancellationEventProvider.notifier)
        .state = const DriverOrderCancellationEvent(
      eventId: 'cancel-order-1',
      orderId: 'order-1',
      orderCode: 'GH-10001',
    );
    await tester.pump();

    expect(cleanupCount, 1);
  });
}
