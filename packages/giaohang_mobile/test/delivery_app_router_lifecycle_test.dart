import 'package:device_preview/device_preview.dart';
import 'package:giaohang_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('preview switches devices without recreating the app router', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const screenKey = ValueKey('preview-screen');
    var factoryCalls = 0;

    await tester.pumpWidget(
      DevicePreview(
        storage: DevicePreviewStorage.none(),
        devices: [Devices.ios.iPhoneSE, Devices.android.samsungGalaxyS20],
        defaultDevice: Devices.ios.iPhoneSE,
        builder: (_) => DeliveryApp(
          initialLocation: '/',
          routerFactory: ({required initialLocation}) {
            factoryCalls++;
            return GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      const Scaffold(key: screenKey, body: TextField()),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final screen = find.byKey(screenKey);
    expect(tester.getSize(screen), Devices.ios.iPhoneSE.screenSize);
    expect(Theme.of(tester.element(screen)).platform, TargetPlatform.iOS);
    expect(find.byType(DeviceFrame), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Delivery address');

    await tester.tap(find.byKey(const Key('model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('android'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Devices.android.samsungGalaxyS20.name));
    await tester.pumpAndSettle();

    expect(tester.getSize(screen), Devices.android.samsungGalaxyS20.screenSize);
    expect(Theme.of(tester.element(screen)).platform, TargetPlatform.android);
    expect(find.text('Delivery address'), findsOneWidget);
    expect(factoryCalls, 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orientation')));
    await tester.pumpAndSettle();
    final portraitSize = Devices.android.samsungGalaxyS20.screenSize;
    expect(
      tester.getSize(screen),
      Size(portraitSize.height, portraitSize.width),
    );
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(screen),
      Size(portraitSize.height, portraitSize.width),
    );
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.byType(DeviceFrame), findsOneWidget);
    expect(factoryCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuilds reuse one router and one auth session controller', (
    tester,
  ) async {
    var factoryCalls = 0;
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    GoRouter routerFactory({required String initialLocation}) {
      factoryCalls++;
      return router;
    }

    await tester.pumpWidget(
      DeliveryApp(initialLocation: '/', routerFactory: routerFactory),
    );
    await tester.pumpWidget(
      DeliveryApp(initialLocation: '/', routerFactory: routerFactory),
    );

    expect(factoryCalls, 1);
  });
}
