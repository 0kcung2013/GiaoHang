import 'package:delivery_app/features/customer/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'dashboard order actions work after returning home from the orders tab',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/customer-home?tab=orders',
        routes: [
          GoRoute(
            path: '/customer-home',
            builder: (context, state) {
              final tab = state.uri.queryParameters['tab'];
              final initialTab = tab == 'orders' ? 1 : 0;
              return CustomerHomeScreen(
                initialTab: initialTab,
                pages: [
                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => context.go('/customer-home?tab=orders'),
                      child: const Text('Open orders'),
                    ),
                  ),
                  const Text('Orders page'),
                  const Text('Tracking page'),
                  const Text('Account page'),
                ],
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Orders page'), findsOneWidget);

      await tester.tap(find.text('Trang chủ'));
      await tester.pumpAndSettle();
      expect(find.text('Open orders'), findsOneWidget);

      await tester.tap(find.text('Open orders'));
      await tester.pumpAndSettle();
      expect(find.text('Orders page'), findsOneWidget);
    },
  );
}
