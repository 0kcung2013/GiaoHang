import 'dart:async';

import 'package:delivery_app/features/driver/cancellation/dialogs/driver_cancel_order_sheet.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_strings.dart';
import 'package:delivery_app/features/driver/cancellation/models/driver_cancellation_policy.dart';
import 'package:delivery_app/features/driver/cancellation/widgets/driver_acceptance_lock_card.dart';
import 'package:delivery_app/features/driver/cancellation/widgets/driver_deadline_countdown.dart';
import 'package:delivery_app/features/driver/cancellation/widgets/driver_cancellation_reason_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  final arrival = DateTime.utc(2026, 9, 27, 10);
  const noArrival = DriverCancellationPolicy(
    status: 'assigned',
    pickupConfirmed: false,
  );
  final arrived = DriverCancellationPolicy(
    status: 'picking_up',
    pickupConfirmed: false,
    pickupArrivedAt: arrival,
  );

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('store cancellation needs an arrival and the full ten minutes', () {
    expect(
      noArrival.allows(DriverCancellationReason.storeClosed, arrival),
      isFalse,
    );
    expect(
      arrived.allows(
        DriverCancellationReason.storeClosed,
        arrival
            .add(const Duration(minutes: 10))
            .subtract(const Duration(milliseconds: 1)),
      ),
      isFalse,
    );
    expect(
      arrived.allows(
        DriverCancellationReason.storeClosed,
        arrival.add(const Duration(minutes: 10)),
      ),
      isTrue,
    );
    expect(
      noArrival.allows(DriverCancellationReason.personal, arrival),
      isTrue,
    );
  });

  test('cannot abandon custody or a terminal order', () {
    for (final status in [
      'delivering',
      'delivered',
      'cancelled',
      'returning',
    ]) {
      final policy = DriverCancellationPolicy(
        status: status,
        pickupConfirmed: false,
        pickupArrivedAt: arrival,
      );
      for (final reason in DriverCancellationReason.values) {
        expect(
          policy.allows(reason, arrival.add(const Duration(hours: 1))),
          isFalse,
        );
      }
    }
    const pickedUp = DriverCancellationPolicy(
      status: 'picking_up',
      pickupConfirmed: true,
    );
    expect(
      pickedUp.allows(DriverCancellationReason.personal, arrival),
      isFalse,
    );
  });

  test('time remaining never goes negative or displays zero early', () {
    expect(
      DriverCancellationPolicy.remaining(
        arrival,
        arrival.add(const Duration(seconds: 1)),
      ),
      Duration.zero,
    );
    expect(
      DriverCancellationPolicy.formatRemaining(const Duration(milliseconds: 1)),
      '00:01',
    );
    expect(
      DriverCancellationPolicy.formatRemaining(const Duration(minutes: 30)),
      '30:00',
    );
  });

  testWidgets('clock catches up after background time and expires once', (
    tester,
  ) async {
    var now = arrival;
    var expiryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverDeadlineCountdown(
            deadline: arrival.add(const Duration(minutes: 30)),
            totalDuration: DriverCancellationPolicy.personalLock,
            now: () => now,
            onExpired: () => expiryCount++,
          ),
        ),
      ),
    );
    expect(find.text('30:00'), findsOneWidget);
    now = arrival.add(const Duration(minutes: 29, seconds: 55));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:05'), findsOneWidget);
    now = arrival.add(const Duration(minutes: 31));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);
    expect(expiryCount, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(expiryCount, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('store option remains disabled until its original deadline', (
    tester,
  ) async {
    var now = arrival.add(const Duration(minutes: 9, seconds: 59));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverCancelOrderSheet(
            policy: arrived,
            now: () => now,
            onConfirm: (_) async {},
          ),
        ),
      ),
    );
    final storeCard = find.ancestor(
      of: find.text(DriverCancellationStrings.storeClosed),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(storeCard).onPressed, isNull);
    expect(
      find.text(DriverCancellationStrings.opensAfter('00:01')),
      findsOneWidget,
    );
    FilledButton confirm() => tester.widget(
      find.widgetWithText(FilledButton, DriverCancellationStrings.confirm),
    );
    expect(confirm().onPressed, isNull);
    now = arrival.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(storeCard).onPressed, isNotNull);
    expect(confirm().onPressed, isNull);
    await tester.tap(find.text(DriverCancellationStrings.storeClosed));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
    expect(
      tester
          .widget<DriverCancellationReasonCard>(
            find.ancestor(
              of: find.text(DriverCancellationStrings.storeClosed),
              matching: find.byType(DriverCancellationReasonCard),
            ),
          )
          .selected,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'personal warning precedes command; double submit is blocked and failure stays open',
    (tester) async {
      var calls = 0;
      final command = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverCancelOrderSheet(
              policy: noArrival,
              now: () => arrival,
              onConfirm: (reason) {
                expect(reason, DriverCancellationReason.personal);
                calls++;
                return command.future;
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text(DriverCancellationStrings.personal));
      await tester.tap(find.text(DriverCancellationStrings.personal));
      await tester.pump();
      expect(
        find.text(DriverCancellationStrings.personalWarning),
        findsOneWidget,
      );
      expect(calls, 0);
      await tester.tap(find.text(DriverCancellationStrings.confirm));
      await tester.pump();
      expect(calls, 1);
      final busyButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, DriverCancellationStrings.submitting),
      );
      expect(busyButton.onPressed, isNull);
      command.completeError(Exception('network'));
      await tester.pumpAndSettle();
      expect(find.text(DriverCancellationStrings.failed), findsOneWidget);
      expect(find.text(DriverCancellationStrings.title), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(375, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('cancellation controls fit $size at text scale 1.6', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: DriverCancelOrderSheet(
                policy: noArrival,
                now: () => arrival,
                onConfirm: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text(DriverCancellationStrings.personal));
      await tester.tap(find.text(DriverCancellationStrings.personal));
      await tester.pump();
      await tester.ensureVisible(find.text(DriverCancellationStrings.confirm));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DriverAcceptanceLockCard(
                  lockedUntil: DateTime.now().add(const Duration(minutes: 30)),
                  onExpired: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
