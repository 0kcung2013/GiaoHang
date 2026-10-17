import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/coverage.dart';
import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/delivery_eta_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_location_step.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/traffic_aware_order_route_layer.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/traffic_demo_route_selector.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'helpers/utraffic_capture_fonts.dart';
import 'support/return_map_test_tiles.dart';

void main() {
  final fixtures =
      jsonDecode(
            File(
              'test/fixtures/eta_simulation_profiles.json',
            ).readAsStringSync(),
          )
          as List;
  setUpAll(() async {
    await ReturnMapTestTiles.prepare();
    await prepareUtrafficCaptureFonts();
  });
  for (final config in [
    (const Size(390, 760), 1.0),
    (const Size(320, 600), 1.6),
  ]) {
    testWidgets(
      'arbitrary held-out route shows synthetic travel time at ${config.$1}',
      (tester) async {
        await tester.binding.setSurfaceSize(config.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final fixture = fixtures.firstWhere(
          (f) => f['name'] == 'HCM_02348_2026-10-07T18:00:00+07:00',
        );
        final raw = fixture['route'],
            profile = DeliveryEtaRouteProfile.fromJson(
              fixture['expected_profile'],
            )!;
        final route = OsrmRouteResult(
          points: profile.points,
          distanceMeters: profile.distanceMeters,
          durationSeconds: (raw['duration'] as num).toDouble(),
          forecastProfile: {
            ...Map<String, dynamic>.from(fixture['expected_profile']),
            'coverage_version': EtaSimulationCoverage.version,
          },
        );
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(config.$2)),
                child: Scaffold(
                  body: OrderLocationStep(
                    initialCenter: profile.points.first,
                    pickup: profile.points.first,
                    delivery: profile.points.last,
                    pickupAddress: 'Điểm lấy trên tuyến mới',
                    deliveryAddress: 'Điểm giao trên tuyến mới',
                    onPickPickup: () {},
                    onPickDelivery: () {},
                    onContinue: (_) {},
                    quotedAt: profile.forecastAt,
                    osrm: _FixedRoute(route),
                    tileProvider: ReturnMapTestTiles(),
                    sampleRoutes: TrafficDemoRouteSelector(
                      selectedId: TrafficDemoScenario.hcmHistoricCongestion.id,
                      onApply: (_) {},
                      onUseSampleRoute: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Mô phỏng lấy'), findsNothing);
        expect(find.text(DeliveryEtaStrings.afterAssignment), findsNothing);
        expect(find.text('Tiếp tục'), findsOneWidget);
        expect(
          tester
              .widget<TrafficAwareOrderRouteLayer>(
                find.byType(TrafficAwareOrderRouteLayer),
              )
              .profile!
              .usesAi,
          isTrue,
        );
        expect(find.text('Ngoài vùng dự đoán AI · ETA từ OSRM'), findsNothing);
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
            final destination = File(
              '../../output/eta_simulation/ui/preview-${config.$1.width.toInt()}.png',
            );
            await destination.parent.create(recursive: true);
            await destination.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _FixedRoute extends OsrmService {
  _FixedRoute(this.route);
  final OsrmRouteResult route;
  @override
  Future<OsrmRouteResult?> getRouteWithWaypoints({
    required List<LatLng> waypoints,
  }) async => route;
}
