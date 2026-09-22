import 'package:delivery_app/core/models/customer_wallet.dart';
import 'package:delivery_app/features/customer/screens/account/widgets/customer_wallet_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';

void main() {
  testWidgets('customer wallet presents balance and demo withdrawal flow', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 900));
    await tester.pumpWidget(const _WalletPreview());

    expect(find.text('VÍ GIAO HÀNG'), findsOneWidget);
    expect(find.text('1.250.000đ'), findsOneWidget);
    expect(find.text('Đã nhận 2.400.000đ'), findsOneWidget);
    expect(find.text('Rút tiền'), findsOneWidget);
    final balancePanel = tester.widget<Container>(
      find.byKey(const ValueKey('customer_wallet_balance_panel')),
    );
    final gradient = (balancePanel.decoration! as BoxDecoration).gradient!;
    expect(gradient.colors, [AppColors.bgCard, AppColors.accentLight]);

    await tester.tap(find.text('Rút tiền'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bản trình diễn · không tạo giao dịch thật'),
      findsOneWidget,
    );
    expect(find.text('Tài khoản nhận (demo)'), findsOneWidget);
    expect(find.text('Xác nhận rút tiền'), findsOneWidget);

    await tester.tap(find.text('Xác nhận rút tiền'));
    await tester.pumpAndSettle();

    expect(find.text('Đã mô phỏng yêu cầu rút 500.000đ.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer wallet history uses existing settlement entries', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 900));
    await tester.pumpWidget(const _WalletPreview());

    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử giao dịch'), findsOneWidget);
    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('Tuần'), findsOneWidget);
    expect(find.text('Tháng'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Tiền vào'), findsOneWidget);
    expect(find.text('Tiền ra'), findsOneWidget);
    expect(find.text('1 GD'), findsOneWidget);

    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();
    expect(find.text('1 GD'), findsOneWidget);

    await tester.tap(find.text('Tháng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tháng '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer wallet supports large accessible text', (tester) async {
    await _setTestViewport(tester, const Size(375, 1000));
    await tester.pumpWidget(
      const _WalletPreview(textScaler: TextScaler.linear(1.6)),
    );

    expect(find.text('Rút tiền'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'wallet must not overflow');
  });
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _WalletPreview extends StatelessWidget {
  const _WalletPreview({this.textScaler = TextScaler.noScaling});

  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: textScaler),
            child: Scaffold(
              backgroundColor: const Color(0xFFFAFAFA),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: CustomerWalletSurface(
                    summary: const CustomerWalletSummary(
                      availableBalance: 1250000,
                      totalReceived: 2400000,
                    ),
                    transactions: [
                      CustomerWalletTransaction(
                        id: 'customer-tx-1',
                        type: 'delivery_credit',
                        amount: 350000,
                        availableDelta: 350000,
                        createdAt: DateTime.now().toUtc(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
