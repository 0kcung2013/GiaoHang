import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:latlong2/latlong.dart';
import 'package:operations_web/features/risk_reports/models/risk_journey.dart';
import 'package:operations_web/features/risk_reports/constants/risk_journey_strings.dart';
import 'package:operations_web/features/support_monitoring/constants/journey_strings.dart';
import 'package:operations_web/features/support_monitoring/widgets/journey_playback.dart';

import 'support_journey_workspace_test.dart' show WorkspaceTiles;

// The first fix is far from the following continuous trace, as in GH-10292.
const oldFix = LatLng(10.808, 106.681);
const pickup = LatLng(11.033096, 106.615973);
const delivery = LatLng(11.035465, 106.619085);
final recordedAt = DateTime.utc(2026, 10, 19, 3, 57, 24);
final journey = RiskJourney([
  RiskJourneyPoint(oldFix, recordedAt, 'driver'),
  for (var i = 0; i < 12; i++)
    RiskJourneyPoint(
      LatLng(11.03073 + i * .00007, 106.622139 - i * .00017),
      recordedAt.add(Duration(seconds: 18 + i * 5)),
      'driver',
    ),
]);

Future<void> mountPlayback(WidgetTester tester, {RiskJourney? trace}) async {
  await tester.binding.setSurfaceSize(const Size(900, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: JourneyPlayback(
            order: const RiskOrderSummary(
              id: 'order',
              trackingCode: 'GH-test',
              status: 'assigned',
              pickupAddress: '',
              deliveryAddress: '',
              pickupLat: 11.033096,
              pickupLng: 106.615973,
              deliveryLat: 11.035465,
              deliveryLng: 106.619085,
            ),
            journey: trace ?? journey,
            mapHeight: 400,
            tileProvider: WorkspaceTiles(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the newest archived GPS rather than the first fix', (
    tester,
  ) async {
    await mountPlayback(tester);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 12);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
      journey.points.last.position,
    );
  });

  testWidgets(
    'initial map frames the latest segment without a distant old fix',
    (tester) async {
      await mountPlayback(tester);
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      expect(
        camera.visibleBounds.contains(journey.points.last.position),
        isTrue,
      );
      expect(camera.visibleBounds.contains(pickup), isTrue);
      expect(camera.visibleBounds.contains(delivery), isTrue);
      expect(camera.visibleBounds.contains(oldFix), isFalse);
    },
  );

  testWidgets('scrubbing keeps the past fix accessible and labels its time', (
    tester,
  ) async {
    await mountPlayback(tester);
    expect(find.text(JourneyStrings.latestGps), findsOneWidget);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0);
    await tester.pumpAndSettle();
    expect(find.text(JourneyStrings.selectedGps), findsOneWidget);
    expect(find.text(RiskJourneyStrings.formatTime(recordedAt)), findsWidgets);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
      oldFix,
    );

    // Returning to the latest fix also stops playback and restores its frame.
    tester
        .widget<FilledButton>(
          find.byWidgetPredicate((widget) => widget is FilledButton),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.tap(find.byTooltip(JourneyStrings.showLatest));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 12);
    expect(find.text(JourneyStrings.pause), findsNothing);
    expect(find.text(JourneyStrings.latestGps), findsOneWidget);
    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    expect(camera.visibleBounds.contains(oldFix), isFalse);
    expect(camera.visibleBounds.contains(journey.points.last.position), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full history still fits every archived sample', (tester) async {
    await mountPlayback(tester);
    await tester.tap(find.byTooltip(JourneyStrings.fit));
    await tester.pumpAndSettle();
    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    expect(camera.visibleBounds.contains(oldFix), isTrue);
    expect(camera.visibleBounds.contains(journey.points.last.position), isTrue);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 12);
  });

  testWidgets('a single archived sample has a position and no playback timer', (
    tester,
  ) async {
    final point = journey.points.last;
    await mountPlayback(tester, trace: RiskJourney([point]));
    expect(find.byType(Slider), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
      point.position,
    );
    await tester.tap(find.byTooltip(JourneyStrings.showLatest));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
