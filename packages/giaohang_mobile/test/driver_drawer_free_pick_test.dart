import 'package:giaohang_mobile/features/driver/screens/widgets/driver_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:giaohang_mobile/core/mobile_app_role.dart';
import 'package:giaohang_mobile/features/help_center/screens/help_center_screen.dart';

void main() {
  testWidgets('driver drawer opens help without changing the selected tab', (
    tester,
  ) async {
    var selectedIndex = 2;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            drawer: DriverDrawer(
              currentIndex: selectedIndex,
              onNavigate: (index) => selectedIndex = index,
            ),
          ),
        ),
        GoRoute(
          path: '/help',
          builder: (_, _) => const HelpCenterScreen(role: MobileAppRole.driver),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hỗ trợ'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpCenterScreen), findsOneWidget);
    expect(selectedIndex, 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HelpCenterScreen), findsNothing);
  });
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
