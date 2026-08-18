import 'package:delivery_app/features/driver/screens/free_pick/widgets/free_pick_map_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('shows the 3 km circle whenever driver position is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 375,
          height: 700,
          child: FreePickMapCanvas(
            driverPosition: const LatLng(10.8, 106.7),
            orders: const [],
            selectedOrderId: null,
            onMapSettled: (_) {},
            onOrderSelected: (_) {},
            onLocate: () {},
            showBaseMap: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final circleLayer = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(circleLayer.circles, hasLength(1));
    expect(circleLayer.circles.single.radius, 3000);
    expect(circleLayer.circles.single.useRadiusInMeter, isTrue);
    expect(find.text('Bán kính tự động 3 km'), findsOneWidget);
    expect(find.byTooltip('Về vị trí hiện tại'), findsOneWidget);
  });
}
