import 'package:delivery_app/features/driver/screens/free_pick/widgets/free_pick_status_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('describes all searchable FreePick orders without a 2 km limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FreePickStatusOverlay(
            count: 2,
            isLoading: false,
            isEnabled: true,
            radiusMeters: 3000,
          ),
        ),
      ),
    );

    expect(find.text('2 đơn tự chọn • 3 km'), findsOneWidget);
  });

  testWidgets('uses neutral loading copy for the searchable viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FreePickStatusOverlay(
            count: 0,
            isLoading: true,
            isEnabled: true,
            radiusMeters: 2500,
          ),
        ),
      ),
    );

    expect(find.text('Đang tìm đơn trong 2,5 km'), findsOneWidget);
  });

  testWidgets('prompts expansion at the default automatic radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FreePickStatusOverlay(
            count: 0,
            isLoading: false,
            isEnabled: true,
            radiusMeters: 2000,
          ),
        ),
      ),
    );

    expect(find.text('Mở rộng bán kính để tìm đơn'), findsOneWidget);
  });
}
