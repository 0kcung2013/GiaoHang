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
import 'package:latlong2/latlong.dart';
import 'helpers/utraffic_capture_fonts.dart';

void main() {
  setUpAll(prepareUtrafficCaptureFonts);
  for (final size in [const Size(320, 600), const Size(390, 760)]) {
    testWidgets('turn speed label, color and braking stages at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = jsonDecode(
        File('test/fixtures/eta_turn_profile.json').readAsStringSync(),
      );
      final p = DeliveryEtaRouteProfile.fromJson(fixture['profile'])!;
      final key = GlobalKey();
      for (final stage in fixture['stages']) {
        final position = LatLng(stage['point'][1], stage['point'][0]);
        final speed = p.speedAt(position), label = '${speed.round()} km/h';
        expect(speed, closeTo(stage['speed_kmh'], 1e-8));
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(size.width == 320 ? 1.6 : 1),
                ),
                child: Scaffold(
                  body: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: p.points[1],
                          initialZoom: 16,
                        ),
                        children: [
                          DeliveryTrafficRouteLayer(
                            segments: p.trafficSegments,
                          ),
                          MarkerLayer(
                            markers: [
                              DeliveryMapMarkers.driver(position),
                              DeliveryMapMarkers.speed(
                                position,
                                speed,
                                level: p.trafficLevelAt(position),
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
                          segments: p.trafficSegments,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(
          tester.widget<Text>(find.text(label)).style!.color,
          deliveryTrafficColor(p.trafficLevelAt(position)),
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('ETA_SIMULATION_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1),
                data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '../../output/eta_simulation/ui/turn-${stage['name']}-${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    });
  }
}
