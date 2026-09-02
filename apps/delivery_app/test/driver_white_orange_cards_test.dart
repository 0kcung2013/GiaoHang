import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/features/driver/screens/earnings/widgets/wallet_balance_hero.dart';
import 'package:delivery_app/features/driver/screens/orders/widgets/driver_orders_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';

void main() {
  testWidgets('driver orders overview uses a white orange surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DriverOrdersOverview(
            isAvailable: true,
            hasActiveOrder: true,
            availableCount: 0,
            activeCount: 1,
            completedCount: 43,
          ),
        ),
      ),
    );

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('driver_orders_overview_card')),
    );
    final decoration = card.decoration! as BoxDecoration;

    expect(decoration.color, AppColors.bgCard);
    expect(decoration.gradient, isNull);
    expect(decoration.border, isNotNull);
  });

  testWidgets('driver wallet balance uses a white orange surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WalletBalanceHero(
            summary: DriverWalletSummary(
              availableBalance: 500000,
              heldBalance: 120000,
              todayIncome: 85000,
            ),
            todayIncome: 85000,
            onTopUp: _noop,
          ),
        ),
      ),
    );

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('driver_wallet_balance_card')),
    );
    final decoration = card.decoration! as BoxDecoration;

    expect(decoration.color, AppColors.bgCard);
    expect(decoration.border, isNotNull);
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
  });
}

void _noop() {}
