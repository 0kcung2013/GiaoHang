import 'dart:async';
import 'package:giaohang_mobile/features/driver/monitoring/widgets/driver_monitoring_panel.dart';
import 'package:giaohang_mobile/features/driver/monitoring/widgets/driver_monitoring_guard.dart';
import 'package:giaohang_mobile/features/driver/monitoring/driver_monitoring_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets(
      'departure modal thresholds, deduplication and resolution $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final stream = StreamController<DriverMonitoringSnapshot>.broadcast();
        addTearDown(stream.close);
        final accepted = DateTime.utc(2026, 10, 17);
        Future<void> emit(
          int minute, {
          bool departed = false,
          bool released = false,
        }) async {
          final now = accepted.add(Duration(minutes: minute));
          stream.add(
            DriverMonitoringSnapshot.fromJson({
              'server_now': now.toIso8601String(),
              'status': 'assigned',
              'released': released,
              'state': DriverMonitoring(
                assignmentId: 'a',
                driverId: 'd',
                acceptedAt: accepted,
                lastReceivedAt: now,
                departedAt: departed ? now : null,
              ).toJson(),
            }),
          );
          await tester.pump();
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              driverMonitoringProvider(
                'o',
              ).overrideWith((ref) => stream.stream),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.6)),
                child: child!,
              ),
              home: DriverMonitoringGuard(
                orderId: 'o',
                onReleased: (_) async {},
                child: DriverMonitoringGuard(
                  orderId: 'o',
                  onReleased: (_) async {},
                  child: const Scaffold(),
                ),
              ),
            ),
          ),
        );
        await emit(4);
        expect(find.byType(Dialog), findsNothing);
        await emit(5);
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text(DriverMonitoringStrings.reminder), findsOneWidget);
        await tester.ensureVisible(
          find.text(DriverMonitoringStrings.acknowledge),
        );
        await tester.tap(find.text(DriverMonitoringStrings.acknowledge));
        await tester.pumpAndSettle();
        await emit(6);
        expect(find.byType(Dialog), findsNothing);
        await emit(8);
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text(DriverMonitoringStrings.warning), findsOneWidget);
        expect(tester.takeException(), isNull);
        await emit(9, departed: true);
        expect(find.byType(Dialog), findsNothing);
        await emit(10, released: true);
        expect(find.byType(Dialog), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  final accepted = DateTime.utc(2026, 10, 11, 10);
  DriverMonitoring monitor({DateTime? last, DateTime? departed}) =>
      DriverMonitoring(
        assignmentId: 'assignment',
        driverId: 'driver',
        acceptedAt: accepted,
        lastReceivedAt: last,
        departedAt: departed,
      );
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('warning and recovery stay readable at $size with large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final now = accepted.add(const Duration(minutes: 8));
      var recoveries = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DriverMonitoringStatusCard(
                state: monitor(last: accepted),
                serverNow: now,
                holdingGoods: false,
                onRecover: () async {
                  recoveries++;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text(DriverMonitoringStrings.missing), findsOneWidget);
      expect(find.text(DriverMonitoringStrings.gpsWarning), findsOneWidget);
      await tester.ensureVisible(find.text(DriverMonitoringStrings.recover));
      await tester.tap(find.text(DriverMonitoringStrings.recover));
      await tester.pumpAndSettle();
      expect(recoveries, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'pickup custody warning never says the goods will be reassigned',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverMonitoringStatusCard(
              state: monitor(last: accepted),
              serverNow: accepted.add(const Duration(minutes: 9)),
              holdingGoods: true,
              onRecover: () async {},
            ),
          ),
        ),
      );
      expect(find.text(DriverMonitoringStrings.custodyWarning), findsOneWidget);
      expect(find.text(DriverMonitoringStrings.gpsWarning), findsNothing);
    },
  );
  testWidgets('fresh GPS with no departure shows warning at minute eight', (
    tester,
  ) async {
    final now = accepted.add(const Duration(minutes: 8));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverMonitoringStatusCard(
            state: monitor(last: now),
            serverNow: now,
            holdingGoods: false,
            onRecover: () async {},
          ),
        ),
      ),
    );
    expect(find.text(DriverMonitoringStrings.warning), findsOneWidget);
    expect(find.text(DriverMonitoringStrings.recover), findsNothing);
  });
  testWidgets(
    'a removed guard does not consume release for the guard still on screen',
    (tester) async {
      final snapshots = StreamController<DriverMonitoringSnapshot>.broadcast();
      addTearDown(snapshots.close);
      var firstHandled = 0;
      var remainingHandled = 0;
      final overrides = [
        driverMonitoringProvider(
          'order',
        ).overrideWith((ref) => snapshots.stream),
      ];
      Widget root({required bool showFirst}) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Column(
            children: [
              if (showFirst)
                DriverMonitoringGuard(
                  key: const ValueKey('first'),
                  orderId: 'order',
                  onReleased: (_) async {
                    firstHandled++;
                  },
                  child: const SizedBox(),
                ),
              DriverMonitoringGuard(
                key: const ValueKey('remaining'),
                orderId: 'order',
                onReleased: (_) async {
                  remainingHandled++;
                },
                child: const SizedBox(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(root(showFirst: true));
      snapshots.add(
        DriverMonitoringSnapshot.fromJson({
          'released': true,
          'support_ticket_id': 'case',
          'server_now': accepted.toIso8601String(),
        }),
      );
      await tester.idle();
      await tester.pumpWidget(root(showFirst: false));
      await tester.pump();
      expect(firstHandled, 0);
      expect(remainingHandled, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'release survives disappearing order and is handled once across duplicate guards',
    (tester) async {
      final snapshots = StreamController<DriverMonitoringSnapshot>.broadcast();
      addTearDown(snapshots.close);
      var handled = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverMonitoringProvider(
              'order',
            ).overrideWith((ref) => snapshots.stream),
          ],
          child: MaterialApp(
            home: DriverMonitoringGuard(
              orderId: 'order',
              onReleased: (ticket) async {
                handled++;
                expect(ticket, 'case');
              },
              child: DriverMonitoringGuard(
                orderId: 'order',
                onReleased: (ticket) async {
                  handled++;
                },
                child: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        snapshots.add(
          DriverMonitoringSnapshot.fromJson({
            'released': true,
            'support_ticket_id': 'case',
            'server_now': accepted.toIso8601String(),
          }),
        );
        await tester.pump();
        await tester.pump();
      }
      expect(handled, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
