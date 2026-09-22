import 'package:delivery_app/core/widgets/delivery_map_markers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('driver map marker uses a compact custom vehicle', (
    tester,
  ) async {
    final marker = DeliveryMapMarkers.driver(const LatLng(10.776, 106.701));

    expect(marker.width, DriverVehicleMarker.size);
    expect(marker.height, DriverVehicleMarker.size);
    expect(marker.alignment, Alignment.center);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: marker.child)),
      ),
    );

    expect(find.byType(DriverVehicleMarker), findsOneWidget);
    expect(find.byKey(const Key('driver-vehicle-marker')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('Vị trí tài xế'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive driver vehicle remains the same marker', (
    tester,
  ) async {
    final marker = DeliveryMapMarkers.driver(
      const LatLng(10.776, 106.701),
      highlight: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: marker.child)),
      ),
    );

    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(DriverVehicleMarker),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.58);
    expect(find.byKey(const Key('driver-vehicle-marker')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver vehicle rotates when heading is available', (
    tester,
  ) async {
    final marker = DeliveryMapMarkers.driver(
      const LatLng(10.776, 106.701),
      bearingDegrees: 90,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: marker.child)),
      ),
    );

    expect(
      find.ancestor(
        of: find.byType(DriverVehicleMarker),
        matching: find.byType(Transform),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('navigation marker centers the vehicle on the GPS route', () {
    final marker = DeliveryMapMarkers.navigationDriver(
      const LatLng(10.776, 106.701),
    );

    expect(marker.width, DriverVehicleMarker.size);
    expect(marker.height, DriverVehicleMarker.size);
    expect(marker.alignment, Alignment.center);
    expect(marker.rotate, isFalse);
  });
}
