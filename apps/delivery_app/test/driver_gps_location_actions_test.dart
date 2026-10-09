import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/features/driver/screens/widgets/driver_gps_debug_components.dart';
import 'package:delivery_app/features/driver/screens/widgets/driver_gps_location_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(
      find.text('Xe sẽ tự chạy theo tuyến từ GPS hiện tại khi bắt đầu chặng.'),
      findsOneWidget,
    );
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
