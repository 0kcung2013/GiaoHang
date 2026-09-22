import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:operations_web/main.dart';

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

    GoRouter routerFactory() {
      factoryCalls++;
      return router;
    }

    await tester.pumpWidget(OperationsApp(routerFactory: routerFactory));
    await tester.pumpWidget(OperationsApp(routerFactory: routerFactory));

    expect(factoryCalls, 1);
  });
}
