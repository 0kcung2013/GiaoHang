import 'package:customer_app/core/widgets/delivery_map_markers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('driver map marker uses the courier mascot asset', (
    tester,
  ) async {
    final marker = DeliveryMapMarkers.driver(const LatLng(10.776, 106.701));

    expect(marker.width, 68);
    expect(marker.height, 68);
    expect(marker.alignment, Alignment.center);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: marker.child)),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    final asset = resized.imageProvider as AssetImage;
    expect(asset.assetName, DeliveryMapMarkers.driverAssetPath);
    expect(find.byKey(const Key('driver-map-marker-icon')), findsOneWidget);
    final stack = tester.widget<Stack>(
      find.byKey(const Key('driver-map-marker-stack')),
    );
    expect(stack.children.first, isA<Image>());
    expect(
      find.byKey(const Key('driver-map-marker-active-dot')),
      findsOneWidget,
    );
    final activeDot = tester.widget<Container>(
      find.byKey(const Key('driver-map-marker-active-dot')),
    );
    final dotDecoration = activeDot.decoration! as BoxDecoration;
    expect(dotDecoration.border, isNull);
    expect(find.bySemanticsLabel('Vị trí tài xế'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive driver marker hides the status dot', (tester) async {
    final marker = DeliveryMapMarkers.driver(
      const LatLng(10.776, 106.701),
      highlight: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: marker.child)),
      ),
    );

    expect(find.byKey(const Key('driver-map-marker-icon')), findsOneWidget);
    expect(find.byKey(const Key('driver-map-marker-active-dot')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('navigation marker centers the mascot on the GPS route', () {
    final marker = DeliveryMapMarkers.navigationDriver(
      const LatLng(10.776, 106.701),
    );

    expect(marker.width, 76);
    expect(marker.height, 76);
    expect(marker.alignment, Alignment.center);
    expect(marker.rotate, isTrue);
  });
}
