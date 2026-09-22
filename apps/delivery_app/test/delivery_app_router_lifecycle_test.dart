import 'package:delivery_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
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
