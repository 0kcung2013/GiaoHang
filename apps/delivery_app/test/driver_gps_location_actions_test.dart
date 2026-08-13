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
            onUseDeviceGps: () => selected = DriverLocationMode.deviceGps,
            onUseDemoHcm: () => selected = DriverLocationMode.demoHcm,
          ),
        ),
      ),
    );

    expect(find.text('Dùng vị trí hiện tại'), findsOneWidget);
    expect(find.text('Dùng vị trí demo TP.HCM'), findsOneWidget);
    expect(find.text('Đo lại GPS'), findsNothing);
    expect(find.text('Đồng bộ'), findsNothing);

    await tester.tap(find.text('Dùng vị trí hiện tại'));
    expect(selected, DriverLocationMode.deviceGps);
  });

  testWidgets('disables both actions while applying a mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGpsLocationActions(
            applyingMode: DriverLocationMode.deviceGps,
            canUseDemo: true,
            onUseDeviceGps: () {},
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
    expect(find.text('Đang lấy vị trí...'), findsOneWidget);
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
}
