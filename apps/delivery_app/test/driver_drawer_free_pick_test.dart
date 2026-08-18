import 'package:delivery_app/features/driver/screens/widgets/driver_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FreePick is available from the driver menu', (tester) async {
    var selectedIndex = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: DriverDrawer(
            currentIndex: 0,
            onNavigate: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('FreePick'), findsOneWidget);
    await tester.tap(find.text('FreePick'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 4);
  });
}
