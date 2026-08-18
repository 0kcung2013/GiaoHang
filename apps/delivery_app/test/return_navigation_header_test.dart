import 'package:delivery_app/core/services/osrm_service.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_position_source.dart';
import 'package:delivery_app/features/returns/widgets/return_navigation_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('shows turn instruction, GPS source and accessible controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        child: ReturnNavigationHeader(
          isApproved: false,
          navigationStep: const OsrmNavigationStep(
            location: LatLng(10.8, 106.7),
            distanceMeters: 250,
            durationSeconds: 40,
            maneuverType: 'turn',
            modifier: 'right',
            roadName: 'Đường DX-091',
          ),
          maneuverDistance: 180,
          remainingDistance: 3400,
          remainingDuration: 600,
          positionSource: DriverPositionSource.simulation,
          onBack: () {},
          onFollowPosition: () {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('return-navigation-instruction')),
      findsOneWidget,
    );
    expect(find.textContaining('Đường DX-091'), findsOneWidget);
    expect(find.text('GPS mô phỏng'), findsOneWidget);
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    expect(find.byTooltip('Theo vị trí tài xế'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        textScaler: const TextScaler.linear(1.6),
        child: ReturnNavigationHeader(
          isApproved: true,
          navigationStep: null,
          maneuverDistance: null,
          remainingDistance: 3400,
          remainingDuration: 600,
          positionSource: DriverPositionSource.targetFallback,
          onBack: () {},
          onFollowPosition: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Tuyến hoàn đã chốt'), findsOneWidget);
  });
}

Widget _testApp({
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: SafeArea(
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    ),
  );
}
