import 'package:operations_web/features/risk_reports/constants/risk_journey_strings.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_journey_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:operations_web/features/risk_reports/data/risk_journey_repository.dart';
import 'package:operations_web/features/risk_reports/models/risk_journey.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/support/constants/support_journey_strings.dart';
import 'package:operations_web/features/support/data/support_order_context_repository.dart';
import 'package:operations_web/features/support/dialogs/support_monitoring_journey_dialog.dart';
import 'package:operations_web/features/support/models/support_monitoring_journey.dart';
import 'package:operations_web/features/support/widgets/support_monitoring_journey_button.dart';
import 'support_monitoring_workflow_test.dart' as fixtures;

const body = 'Nhận đơn: 11/10/2026 13:40:00\nPhát hiện: 11/10/2026 13:50:00';
final event = DateTime.utc(2026, 10, 11, 6, 50);
RiskJourneyPoint point(int minutes, String driver) => RiskJourneyPoint(
  const LatLng(10.77, 106.7),
  event.add(Duration(minutes: minutes)),
  driver,
);

class JourneyRepository implements RiskJourneyRepository {
  bool fail = false;
  int calls = 0;
  RiskJourney journey = RiskJourney([]);
  @override
  Future<RiskJourney> fetch(String orderId) async {
    calls++;
    if (fail) throw StateError('offline');
    return journey;
  }
}

class OrderRepository implements SupportOrderContextRepository {
  @override
  Future<SupportOrderContextData> fetch(String orderId) async =>
      SupportOrderContextData(
        order: RiskOrderSummary.fromJson({
          'id': orderId,
          'driver_id': 'replacement',
        }),
      );
}

class JourneyTiles extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAADTED8xAAACwUlEQVR4nO3TsQkAIADAMPX/awXB0TMcmlzQpXOfO6Bq/Q6AnwxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgDQDkGYA0gxAmgFIMwBpBiDNAKQZgFH2AIjYBN8uQWF/AAAAAElFTkSuQmCC',
    ),
  );
}

void main() {
  test('historical interval uses Vietnam server time and original driver', () {
    final scope = SupportMonitoringJourney(
      fixtures.monitoringTicket({'message': body}),
    );
    expect(scope.end, event);
    final selected = scope.select(
      RiskJourney([
        point(-11, 'former-driver'),
        point(-10, 'former-driver'),
        point(-1, 'replacement'),
        point(0, 'former-driver'),
        point(1, 'replacement'),
      ], unavailableChunks: 2),
    );
    expect(selected.points.map((p) => p.driverId), [
      'former-driver',
      'former-driver',
    ]);
    expect(selected.unavailableChunks, 2);
  });

  test(
    'customer scope refuses ambiguous drivers; invalid bounds stay empty',
    () {
      final scope = SupportMonitoringJourney(
        fixtures.monitoringTicket({
          'message': body,
          'requester_role': 'customer',
        }),
      );
      expect(
        scope.select(RiskJourney([point(-1, 'old')])).points.single.driverId,
        'old',
      );
      expect(
        scope.select(RiskJourney([point(-1, 'old'), point(0, 'new')])).points,
        isEmpty,
      );
      for (final message in [
        '',
        body.replaceAll('11/10', '32/10'),
        body.replaceFirst('13:40', '14:40'),
      ]) {
        expect(
          SupportMonitoringJourney(
            fixtures.monitoringTicket({'message': message}),
          ).hasWindow,
          isFalse,
        );
      }
    },
  );

  testWidgets('entry opens historical viewer without accepting ticket', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportMonitoringJourneyButton(
            ticket: fixtures.monitoringTicket(),
          ),
        ),
      ),
    );
    await tester.tap(find.text(SupportJourneyStrings.open));
    await tester.pumpAndSettle();
    expect(find.text(SupportJourneyStrings.missingWindow), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportMonitoringJourneyDialog), findsNothing);
  });

  for (final size in [const Size(375, 568), const Size(1280, 850)]) {
    testWidgets('populated journey remains scrollable at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = JourneyRepository()
        ..journey = RiskJourney([
          point(-10, 'former-driver'),
          point(0, 'former-driver'),
          point(1, 'replacement'),
        ]);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(size.width < 600 ? 1.6 : 1),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SupportMonitoringJourneyDialog(
              ticket: fixtures.monitoringTicket({'message': body}),
              journeyRepository: repository,
              orderRepository: OrderRepository(),
              tileProvider: JourneyTiles(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = tester.widget<RiskJourneyMap>(find.byType(RiskJourneyMap));
      expect(map.journey.points, hasLength(2));
      expect(map.order.driverId, 'replacement');
      expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
      await tester.ensureVisible(find.text(RiskJourneyStrings.reload));
      await tester.pumpAndSettle();
      expect(
        find.text(RiskJourneyStrings.reload).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('empty, error and retry at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = JourneyRepository()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(size.width < 600 ? 1.6 : 1),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SupportMonitoringJourneyDialog(
              ticket: fixtures.monitoringTicket({'message': body}),
              journeyRepository: repository,
              orderRepository: OrderRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa tải được hành trình'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.text('Tải lại hành trình'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(
        find.text(
          DateTime.now().difference(event).inDays > 14
              ? SupportJourneyStrings.expired
              : SupportJourneyStrings.empty,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
