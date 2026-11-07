import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/features/driver/screens/widgets/driver_gps_debug_components.dart';
import 'package:giaohang_mobile/features/driver/screens/widgets/driver_gps_location_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'helpers/utraffic_capture_fonts.dart';

void main() {
  setUpAll(prepareUtrafficCaptureFonts);
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('relative demo controls fit $size with 160% text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.6),
            ),
            child: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                backgroundColor: AppColors.bgWarm,
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const DriverGpsDemoBanner(
                        locationMode: DriverLocationMode.demoCurrentPosition,
                        hasOffset: true,
                        isDemoAccount: true,
                        offsetMeters: 160,
                      ),
                      const SizedBox(height: 16),
                      DriverGpsLocationActions(
                        applyingMode: null,
                        canUseDemo: true,
                        onUseDemoCurrentPosition: () {},
                        onUseDemoHcm: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Lệch GPS thiết bị khoảng 160 m'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('use-demo-current-position')))
            .height,
        greaterThanOrEqualTo(48),
      );
      if (size.width == 390) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '../../artifacts/driver_demo_relative_controls.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets('shows current and TP.HCM demo actions instead of old actions', (
    tester,
  ) async {
    var selected = DriverLocationMode.demoHcm;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGpsLocationActions(
            applyingMode: null,
            canUseDemo: true,
            onUseDemoCurrentPosition: () =>
                selected = DriverLocationMode.demoCurrentPosition,
            onUseDemoHcm: () => selected = DriverLocationMode.demoHcm,
          ),
        ),
      ),
    );

    expect(find.text('Dùng vị trí hiện tại'), findsNothing);
    expect(find.text('Dùng vị trí demo TP.HCM'), findsOneWidget);
    expect(find.text('Mô phỏng từ vị trí hiện tại'), findsOneWidget);
    expect(find.text('Đo lại GPS'), findsNothing);
    expect(find.text('Đồng bộ'), findsNothing);

    await tester.tap(find.text('Mô phỏng từ vị trí hiện tại'));
    expect(selected, DriverLocationMode.demoCurrentPosition);
  });

  testWidgets('disables both actions while applying a mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGpsLocationActions(
            applyingMode: DriverLocationMode.demoCurrentPosition,
            canUseDemo: true,
            onUseDemoCurrentPosition: () {},
            onUseDemoHcm: () {},
          ),
        ),
      ),
    );

    final buttons = tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(buttons, hasLength(2));
    expect(buttons.every((button) => button.onPressed == null), isTrue);
    expect(find.text('Đang bật mô phỏng...'), findsOneWidget);
  });

  testWidgets('banner explains when current device location is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DriverGpsDemoBanner(
            locationMode: DriverLocationMode.deviceGps,
            hasOffset: true,
            isDemoAccount: true,
            offsetMeters: 1000,
          ),
        ),
      ),
    );

    expect(find.text('Đang dùng vị trí hiện tại'), findsOneWidget);
    expect(
      find.text('Tuyến đường và khoảng cách sẽ tính từ GPS thiết bị.'),
      findsOneWidget,
    );
  });

  testWidgets('banner identifies route simulation from current GPS', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DriverGpsDemoBanner(
            locationMode: DriverLocationMode.demoCurrentPosition,
            hasOffset: true,
            isDemoAccount: true,
            offsetMeters: 1000,
          ),
        ),
      ),
    );

    expect(find.text('Đang mô phỏng từ vị trí hiện tại'), findsOneWidget);
    expect(find.text('Lệch GPS thiết bị khoảng 1000 m'), findsOneWidget);
  });

  testWidgets('two demo actions fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGpsLocationActions(
            applyingMode: null,
            canUseDemo: true,
            onUseDemoCurrentPosition: () {},
            onUseDemoHcm: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('use-demo-current-position')),
      findsOneWidget,
    );
  });
}
