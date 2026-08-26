import 'package:delivery_app/features/driver/screens/home/driver_home_strings.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_wallet_balance_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wallet notice presents the balance in a centered dialog', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 812));
    DriverWalletBalanceAction? selectedAction;

    await tester.pumpWidget(
      _DialogPreview(
        availableBalance: 750000,
        textScaler: TextScaler.noScaling,
        onResult: (value) => selectedAction = value,
      ),
    );
    await tester.tap(find.text('Mở thông báo'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text(DriverHomeStrings.onlineWalletTitle), findsOneWidget);
    expect(find.text('750.000đ'), findsOneWidget);
    expect(find.text(DriverHomeStrings.walletContinueAction), findsOneWidget);
    expect(find.text(DriverHomeStrings.walletTopUpAction), findsOneWidget);
    final primaryAction = find.byKey(const ValueKey('wallet-primary-action'));
    expect(tester.getSize(primaryAction).height, greaterThanOrEqualTo(48));
    expect(
      find.descendant(
        of: primaryAction,
        matching: find.text(DriverHomeStrings.walletContinueAction),
      ),
      findsOneWidget,
    );
    await tester.tap(primaryAction);
    await tester.pumpAndSettle();
    expect(selectedAction, DriverWalletBalanceAction.continueOnline);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty wallet notice remains usable with large text', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 812));
    DriverWalletBalanceAction? selectedAction;

    await tester.pumpWidget(
      _DialogPreview(
        availableBalance: 0,
        textScaler: TextScaler.linear(2),
        onResult: (value) => selectedAction = value,
      ),
    );
    await tester.tap(find.text('Mở thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('0đ'), findsOneWidget);
    expect(find.text(DriverHomeStrings.walletTopUpNowAction), findsOneWidget);
    expect(find.text(DriverHomeStrings.walletLaterAction), findsOneWidget);
    final primaryAction = find.byKey(const ValueKey('wallet-primary-action'));
    expect(
      find.descendant(
        of: primaryAction,
        matching: find.text(DriverHomeStrings.walletTopUpNowAction),
      ),
      findsOneWidget,
    );
    await tester.tap(primaryAction);
    await tester.pumpAndSettle();
    expect(selectedAction, DriverWalletBalanceAction.topUp);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _DialogPreview extends StatelessWidget {
  const _DialogPreview({
    required this.availableBalance,
    required this.textScaler,
    required this.onResult,
  });

  final int availableBalance;
  final TextScaler textScaler;
  final ValueChanged<DriverWalletBalanceAction?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  final result = await showDriverWalletBalanceDialog(
                    context,
                    availableBalance: availableBalance,
                  );
                  onResult(result);
                },
                child: const Text('Mở thông báo'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
