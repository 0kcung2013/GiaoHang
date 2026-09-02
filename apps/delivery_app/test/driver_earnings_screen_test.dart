import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/features/driver/screens/earnings/widgets/driver_wallet_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wallet view emphasizes available held and today income', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverWalletContent(
            summary: const DriverWalletSummary(
              availableBalance: 500000,
              heldBalance: 123750,
              todayIncome: 21250,
            ),
            transactions: [
              DriverWalletTransaction.fromJson({
                'id': 'tx-1',
                'transaction_type': 'vnpay_topup',
                'status': 'completed',
                'amount': 500000,
                'available_delta': 500000,
                'held_delta': 0,
                'created_at': '2026-08-17T02:00:00Z',
              }),
              DriverWalletTransaction.fromJson({
                'id': 'tx-2',
                'transaction_type': 'prepaid_earning',
                'status': 'completed',
                'amount': 21250,
                'available_delta': 21250,
                'held_delta': 0,
                'created_at': '2026-08-17T03:00:00Z',
              }),
            ],
            onTopUp: () {},
            now: DateTime.parse('2026-08-17T04:00:00Z'),
          ),
        ),
      ),
    );

    expect(find.text('500.000đ'), findsOneWidget);
    expect(find.text('Đang giữ'), findsOneWidget);
    expect(find.text('123.750đ'), findsOneWidget);
    expect(find.text('Thu nhập hôm nay'), findsOneWidget);
    expect(find.text('+21.250đ'), findsWidgets);
    expect(find.text('Nạp qua VNPAY'), findsOneWidget);
    expect(find.text('Rút'), findsOneWidget);
    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('Tuần'), findsOneWidget);
    expect(find.text('Tháng'), findsOneWidget);

    await tester.tap(find.text('Tuần'));
    await tester.pump();

    expect(find.text('17/08 – 23/08'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Nạp ví'), 300);

    expect(find.text('+500.000đ'), findsOneWidget);
    expect(find.text('Nạp ví'), findsOneWidget);
    expect(find.text('Hôm nay · 17/08/2026'), findsOneWidget);
  });

  testWidgets('shows one COD debit and includes return earning in income', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverWalletContent(
            summary: const DriverWalletSummary(
              availableBalance: 404000,
              heldBalance: 0,
              todayIncome: 54000,
            ),
            transactions: [
              _transaction('hold', 'cod_hold', 350000, '2026-08-18T02:14:00Z'),
              _transaction(
                'capture',
                'cod_advance_capture',
                350000,
                '2026-08-18T02:16:00Z',
              ),
              _transaction(
                'return-delivery-income',
                'return_delivery_earning',
                36000,
                '2026-08-18T02:22:00Z',
              ),
              _transaction(
                'return-income',
                'return_earning',
                18000,
                '2026-08-18T02:23:00Z',
              ),
            ],
            onTopUp: () {},
            now: DateTime.parse('2026-08-18T04:00:00Z'),
          ),
        ),
      ),
    );

    expect(find.text('+54.000đ'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Ứng tiền hàng'), 300);
    expect(find.text('-350.000đ'), findsOneWidget);
    expect(find.text('Ứng tiền hàng'), findsOneWidget);
    expect(find.text('Cước giao của đơn hoàn'), findsOneWidget);
    expect(find.text('Phí hoàn hàng'), findsOneWidget);
    expect(find.text('Giữ tiền COD'), findsNothing);
    expect(find.text('3 giao dịch'), findsNWidgets(2));
  });

  testWidgets('pending top-up is not presented as credited money', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverWalletContent(
            summary: const DriverWalletSummary(
              availableBalance: 0,
              heldBalance: 0,
              todayIncome: 0,
            ),
            transactions: [
              DriverWalletTransaction.fromJson({
                'id': 'tx-pending',
                'transaction_type': 'vnpay_topup',
                'status': 'pending',
                'amount': 500000,
                'available_delta': 0,
                'held_delta': 0,
                'created_at': '2026-08-14T13:23:00Z',
              }),
            ],
            onTopUp: () {},
            now: DateTime.parse('2026-08-14T14:00:00Z'),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Đang xử lý'), 300);

    expect(find.text('Đang xử lý'), findsOneWidget);
    expect(find.text('+500.000đ'), findsNothing);
    expect(find.text('500.000đ'), findsOneWidget);
  });

  testWidgets('wallet layout supports 375px width and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: DriverWalletContent(
              summary: const DriverWalletSummary(
                availableBalance: 1250000,
                heldBalance: 120000,
                todayIncome: 85000,
              ),
              transactions: const [],
              onTopUp: () {},
              now: DateTime.utc(2026, 8, 17, 4),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

DriverWalletTransaction _transaction(
  String id,
  String type,
  int amount,
  String createdAt,
) {
  return DriverWalletTransaction.fromJson({
    'id': id,
    'transaction_type': type,
    'status': 'completed',
    'amount': amount,
    'available_delta': type == 'cod_hold' ? -amount : amount,
    'held_delta': type == 'cod_hold' ? amount : 0,
    'created_at': createdAt,
  });
}
