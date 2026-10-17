import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/widgets/delivery_map_markers.dart';
import 'package:giaohang_mobile/core/widgets/delivery_traffic_map_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/utraffic_capture_fonts.dart';
import 'support/return_map_test_tiles.dart';

void main() {
  setUpAll(() async {
    await ReturnMapTestTiles.prepare();
    await prepareUtrafficCaptureFonts();
  });
  for (final size in [const Size(320, 600), const Size(390, 760)]) {
    testWidgets(
      'off-peak moving speed label follows segment speed and color at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final fixtures =
            jsonDecode(
                  File(
                    'test/fixtures/eta_simulation_profiles.json',
                  ).readAsStringSync(),
                )
                as List;
        final raw = fixtures.firstWhere(
          (f) => f['name'] == 'HCM_02348_2026-10-07T12:00:00+07:00',
        )['expected_profile'];
        final profile = DeliveryEtaRouteProfile.fromJson(raw)!;
        final initial = profile.points[profile.points.length ~/ 2];
        final next = profile.points.lastWhere(
          (p) => profile.speedAt(p).round() != profile.speedAt(initial).round(),
        );
        final controller = MapController(), capture = GlobalKey();
        Future<void> show(int step) async {
          final point = step == 0 ? initial : next;
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(size.width == 320 ? 1.6 : 1),
                  ),
                  child: Scaffold(
                    body: Stack(
                      children: [
                        FlutterMap(
                          mapController: controller,
                          options: MapOptions(
                            initialCenter: initial,
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              tileProvider: ReturnMapTestTiles(),
                            ),
                            DeliveryTrafficRouteLayer(
                              segments: profile.trafficSegments,
                            ),
                            MarkerLayer(
                              markers: [
                                DeliveryMapMarkers.driver(point),
                                DeliveryMapMarkers.speed(
                                  point,
                                  profile.speedAt(point),
                                  level: profile.trafficLevelAt(point),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 24,
                          child: DeliveryTrafficMapLegend(
                            segments: profile.trafficSegments,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          controller.move(point, 15);
          await tester.pumpAndSettle();
          expect(
            find.text('${profile.speedAt(point).round()} km/h'),
            findsOneWidget,
          );
          final label = tester.widget<Text>(
            find.text('${profile.speedAt(point).round()} km/h'),
          );
          expect(
            label.style!.color,
            deliveryTrafficColor(profile.trafficLevelAt(point)),
          );
          expect(tester.takeException(), isNull);
        }

        await show(0);
        await show(1);
        if (const bool.fromEnvironment('ETA_SIMULATION_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '../../output/eta_simulation/ui/moving-speed-${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }
}
