import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:delivery_app/core/widgets/delivery_map_markers.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_map_start_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(_prepareTestFonts);
  for (final viewport in [const Size(320, 600), const Size(390, 760)]) {
    for (final rotation in [0.0, 90.0]) {
      testWidgets(
        'speed stays beside GPS vehicle at $viewport with $rotation degree map rotation',
        (tester) async {
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          const position = LatLng(10.7849, 106.6684);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: viewport,
                  textScaler: TextScaler.linear(1.6),
                ),
                child: Scaffold(
                  body: RepaintBoundary(
                    key: const ValueKey('speed-map-qa'),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: position,
                        initialZoom: 15,
                        initialRotation: rotation,
                      ),
                      children: [
                        MarkerLayer(
                          // Khách không counter-rotate cả layer; tài xế có dùng.
                          rotate: rotation != 0,
                          markers: [
                            DeliveryMapMarkers.navigationDriver(position),
                            DeliveryMapMarkers.speed(position, 30),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final vehicleCenter = tester.getCenter(
            find.byType(DriverVehicleMarker),
          );
          final speedRect = tester.getRect(find.byType(DriverSpeedLabel));
          expect(
            speedRect.left - vehicleCenter.dx - DriverVehicleMarker.size / 2,
            closeTo(AppSpacing.sm, 0.1),
          );
          expect(speedRect.center.dy, closeTo(vehicleCenter.dy, 0.1));
          expect(speedRect.width, closeTo(DriverSpeedLabel.width, 0.1));
          expect(speedRect.right, lessThan(viewport.width));
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('ETA_VISUAL_QA')) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('speed-map-qa')),
            );
            await tester.runAsync(() async {
              final picture = await boundary.toImage().timeout(
                const Duration(seconds: 15),
              );
              final bytes = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('../../.tmp/eta-visual');
              await dir.create(recursive: true);
              await File(
                '${dir.path}/speed-side-${viewport.width.toInt()}-${rotation.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              picture.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'Start and Stop dispatch independent actions with no extra status badge',
    (tester) async {
      var starts = 0, stops = 0;
      Future<void> pump(bool running) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverMapStartControl(
              running: running,
              onStart: () => starts++,
              onStop: () => stops++,
            ),
          ),
        ),
      );
      await pump(false);
      await tester.tap(find.text('Start'));
      expect(starts, 1);
      expect(stops, 0);
      await pump(true);
      await tester.tap(find.text('Stop'));
      expect(starts, 1);
      expect(stops, 1);
      expect(find.text('Đang mô phỏng'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final viewport in [const Size(320, 600), const Size(390, 760)]) {
    testWidgets('round driver and speed labels fit $viewport at large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: TextScaler.linear(1.6),
            ),
            child: Scaffold(
              backgroundColor: AppColors.bgLight,
              body: Center(
                child: RepaintBoundary(
                  key: const ValueKey('speed-qa'),
                  child: Container(
                    width: viewport.width - 32,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: AppRadius.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final speed in [30.0, 50.0, 0.0])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const DriverVehicleMarker(isActive: true),
                                SizedBox(
                                  width: 96,
                                  height: 32,
                                  child: DriverSpeedLabel(speedKmh: speed),
                                ),
                                DriverMapStartControl(
                                  running: speed > 0,
                                  onStart: () {},
                                  onStop: () {},
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('30 km/h'), findsOneWidget);
      expect(find.text('50 km/h'), findsOneWidget);
      expect(find.text('0 km/h'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('ETA_VISUAL_QA')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('speed-qa')),
        );
        await tester.runAsync(() async {
          final picture = await boundary.toImage().timeout(
            const Duration(seconds: 15),
          );
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final dir = Directory('../../.tmp/eta-visual');
          await dir.create(recursive: true);
          await File(
            '${dir.path}/speed-${viewport.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _prepareTestFonts() async {
  final configFile = File('../../.dart_tool/package_config.json');
  final config = jsonDecode(await configFile.readAsString()) as Map;
  final flutterPackage =
      (config['packages'] as List).firstWhere(
            (dynamic package) => package['name'] == 'flutter',
          )
          as Map;
  final flutterUri = configFile.absolute.uri.resolve(
    '${flutterPackage['rootUri']}/',
  );
  final fallback = await File.fromUri(
    flutterUri.resolve('../flutter_tools/static/Ahem.ttf'),
  ).readAsBytes();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File.fromUri(
        flutterUri.resolve(
          '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ),
      ).readAsBytes().then(ByteData.sublistView),
    );
  await icons.load();
  const variants = ['Regular', 'Medium', 'SemiBold'];
  final manifest = <String, Object>{
    for (final variant in variants)
      'fonts/PlusJakartaSans-$variant.ttf': [
        {'asset': 'fonts/PlusJakartaSans-$variant.ttf'},
      ],
  };
  final fonts = <String, ByteData>{};
  for (final variant in variants) {
    final file = File('../../.tmp/PlusJakartaSans-$variant.ttf');
    final regular = File('../../.tmp/PlusJakartaSans-Regular.ttf');
    fonts['fonts/PlusJakartaSans-$variant.ttf'] = ByteData.sublistView(
      file.existsSync()
          ? await file.readAsBytes()
          : regular.existsSync()
          ? await regular.readAsBytes()
          : fallback,
    );
  }
  final marker = await File(
    'assets/images/delivery_scooter_marker.svg',
  ).readAsBytes();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(manifest);
        }
        if (key == 'assets/images/delivery_scooter_marker.svg') {
          return ByteData.sublistView(marker);
        }
        return fonts[key];
      });
  for (final weight in [FontWeight.w400, FontWeight.w500, FontWeight.w600]) {
    GoogleFonts.plusJakartaSans(fontWeight: weight);
  }
  await GoogleFonts.pendingFonts();
}
