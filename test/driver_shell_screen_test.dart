import 'package:customer_app/features/driver/screens/driver_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('GPS debug action is in the AppBar and does not float', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DriverShellScreen())),
    );
    await tester.pump();

    final gpsAction = find.byTooltip('Kiểm tra vị trí');
    expect(gpsAction, findsOneWidget);
    expect(
      find.ancestor(of: gpsAction, matching: find.byType(AppBar)),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
