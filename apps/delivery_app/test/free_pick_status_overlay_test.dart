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
          ),
        ),
      ),
    );

    expect(find.text('2 đơn có thể nhận'), findsOneWidget);
    expect(find.textContaining('ngoài 2 km'), findsNothing);
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
          ),
        ),
      ),
    );

    expect(find.text('Đang tìm đơn có thể nhận'), findsOneWidget);
    expect(find.textContaining('ngoài vùng tự động'), findsNothing);
  });
}
