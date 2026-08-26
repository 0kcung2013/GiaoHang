import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_wallet_debit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pickup debit dialog shows amount and remaining balance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDriverWalletDebitDialog(
                  context: context,
                  debitedAmount: 500000,
                  availableBalance: 200000,
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    expect(find.text('ĐÃ ỨNG TIỀN HÀNG'), findsOneWidget);
    expect(find.text('−500.000đ'), findsOneWidget);
    expect(find.text('200.000đ'), findsOneWidget);
    expect(find.text('Tiếp tục giao hàng'), findsOneWidget);
  });
}
