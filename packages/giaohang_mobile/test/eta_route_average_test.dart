import 'dart:io';
import 'dart:ui' as ui;
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/delivery_eta_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/eta_ai_detail_panel.dart';
import 'package:giaohang_mobile/features/delivery_eta/models/order_eta.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'helpers/utraffic_capture_fonts.dart';

DeliveryEtaEstimate preview() {
  final profile = DeliveryEtaRouteProfile.fromJson({
    'distance_meters': 2000,
    'forecast_at': '2026-10-13T05:00:00Z',
    'used_ai': true,
    'is_synthetic': true,
    'model_version': 'hcm_synthetic_segment_speed_v1',
    'color_metric': 'speed_kmh',
    'route_points': [
      [106.6, 10.75],
      [106.62, 10.75],
    ],
    'speed_profile': [
      {'start_meters': 0, 'end_meters': 1000, 'speed_kmh': 40},
      {'start_meters': 1000, 'end_meters': 2000, 'speed_kmh': 20},
    ],
  })!;
  return DeliveryEtaCalculator.calculate(
    distanceMeters: 2000,
    quotedAt: profile.forecastAt,
    routePoints: profile.points,
    speedProfile: profile,
  );
}

OrderEta accepted({dynamic approach, dynamic delivery}) => OrderEta(
  data: {
    'approach': approach,
    'delivery': delivery,
    'preparation_minutes': 5,
    'pickup_minutes': 5,
    'handoff_minutes': 5,
  },
  serverNow: DateTime.utc(2026),
  observedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (const bool.fromEnvironment('ETA_SIMULATION_CAPTURE')) {
      await prepareUtrafficCaptureFonts();
    }
  });
  test(
    'whole-route moving average preserves travel time and excludes handling',
    () {
      final eta = preview();
      expect(eta.averageSpeedKmh, closeTo(26.6666666667, 1e-8));
      expect(
        eta.averageSpeedKmh,
        isNot(30),
      ); // Equal distances at 40/20 need a harmonic mean.
      expect(
        eta.distanceMeters * .06 / eta.averageSpeedKmh!,
        closeTo(4.5, 1e-8),
      );
      expect(eta.calibratedTravelMinutes, 4.5);
      expect(eta.minMinutes, 10); // Five-minute handling remains separate.
    },
  );
  test(
    'accepted summary uses both legs and the same moving average as preview',
    () {
      final eta = accepted(
        approach: {'distance_meters': 1000, 'travel_minutes': 1.5},
        delivery: {'distance_meters': 1000, 'travel_minutes': 3},
      );
      expect(eta.distanceMeters, 2000);
      expect(eta.averageSpeedKmh, closeTo(preview().averageSpeedKmh!, 1e-8));
    },
  );
  test('legacy or malformed summaries do not invent a route speed', () {
    for (final leg in [
      null,
      {'travel_minutes': 3},
      {'distance_meters': 1000, 'travel_minutes': 0},
      {'distance_meters': double.nan, 'travel_minutes': 3},
      {'distance_meters': 1000, 'travel_minutes': double.infinity},
      {'distance_meters': -100, 'travel_minutes': 3},
    ]) {
      expect(
        accepted(
          approach: leg,
          delivery: {'distance_meters': 1000, 'travel_minutes': 3},
        ).averageSpeedKmh,
        isNull,
      );
    }
    final zero = accepted(
      approach: {'distance_meters': 0, 'travel_minutes': 0},
      delivery: {'distance_meters': 1000, 'travel_minutes': 3},
    );
    expect(zero.averageSpeedKmh, 20);
  });
  for (final config in [
    (const Size(320, 600), 1.6),
    (const Size(390, 760), 1.0),
  ]) {
    testWidgets(
      'AI summary shows distance, average speed and travel time at ${config.$1}',
      (tester) async {
        await tester.binding.setSurfaceSize(config.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final capture = GlobalKey(), eta = preview();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(config.$2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: EtaAiDetailPanel(eta: eta),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('eta-ai-details-toggle')));
        await tester.pumpAndSettle();
        expect(find.text(DeliveryEtaStrings.simulatedTraffic), findsOneWidget);
        expect(find.text(DeliveryEtaStrings.distanceLabel), findsOneWidget);
        expect(find.text('2,00 km'), findsOneWidget);
        expect(find.text(DeliveryEtaStrings.averageSpeedLabel), findsOneWidget);
        expect(find.text('26,7 km/h'), findsOneWidget);
        expect(find.text(DeliveryEtaStrings.travelLabel), findsOneWidget);
        expect(
          find.text(DeliveryEtaStrings.aiRangeExplanation),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('ETA_SIMULATION_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '../../output/eta_simulation/ui/eta-summary-${config.$1.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
