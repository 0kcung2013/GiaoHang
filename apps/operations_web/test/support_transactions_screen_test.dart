import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support_transactions/dialogs/transaction_detail_dialog.dart';
import 'package:operations_web/features/support_transactions/models/support_transaction.dart';
import 'package:operations_web/features/support_transactions/screens/support_transactions_screen.dart';
import 'helpers/transaction_test_repository.dart';

void main() {
  testWidgets(
    'search is debounced, groups fetch independently, and details open',
    (tester) async {
      final repo = TransactionTestRepository();
      await _mount(tester, repo);
      expect(find.text('VNPAY-topups'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('transaction-search')),
        'VNPAY-old',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.calls, hasLength(1));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(repo.calls.last.search, 'VNPAY-old');
      await tester.tap(find.text('Thanh toán đơn'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.group, TransactionGroup.payments);
      await tester.tap(find.text('VNPAY-payments'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionDetailDialog), findsOneWidget);
      expect(find.text('Chi tiết giao dịch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('error is visible with retry, empty results are distinguished', (
    tester,
  ) async {
    final repo = TransactionTestRepository()..fail = true;
    await _mount(tester, repo);
    expect(find.textContaining('Không thể tải giao dịch'), findsOneWidget);
    repo.fail = false;
    repo.loader = (g, s, b) async => TransactionPage(
      rows: [],
      hasMore: false,
      serverNow: DateTime.utc(2026),
    );
    await tester.tap(find.text('Tải lại').last);
    await tester.pumpAndSettle();
    expect(find.text('Không có giao dịch phù hợp'), findsOneWidget);
  });
  testWidgets('load more uses a cursor and keeps previous results', (
    tester,
  ) async {
    final repo = TransactionTestRepository()
      ..loader = (g, s, b) async => TransactionPage(
        rows: [transactionFixture(id: b == null ? 'first' : 'second')],
        hasMore: b == null,
        serverNow: DateTime.utc(2026),
      );
    await _mount(tester, repo);
    await tester.ensureVisible(find.text('Xem thêm'));
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(find.text('VNPAY-first'), findsOneWidget);
    expect(find.text('VNPAY-second'), findsOneWidget);
    expect(repo.calls.last.before?.id, 'first');
  });
  testWidgets(
    'records a support request with immutable transaction/user context',
    (tester) async {
      final repo = TransactionTestRepository();
      await _mount(tester, repo);
      await tester.tap(find.text('VNPAY-topups'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ghi nhận yêu cầu hỗ trợ'));
      await tester.tap(find.text('Ghi nhận yêu cầu hỗ trợ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu yêu cầu'));
      await tester.pumpAndSettle();
      expect(repo.created, isEmpty);
      await tester.enterText(
        find.byKey(const Key('transaction-request-message')),
        'Ngân hàng đã trừ tiền nhưng ví chưa được cộng.',
      );
      await tester.tap(find.text('Lưu yêu cầu'));
      await tester.pumpAndSettle();
      expect(repo.created.single.requesterId, 'user-1');
      expect(repo.created.single.orderId, isNull);
      expect(repo.created.single.message, contains('[GD:driver:topups]'));
      expect(find.text('Đã ghi nhận yêu cầu hỗ trợ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late request response is safe after closing the dialog', (
    tester,
  ) async {
    final repo = TransactionTestRepository();
    await _mount(tester, repo);
    await tester.tap(find.text('VNPAY-topups'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'small screen with large text keeps all five destinations usable',
    (tester) async {
      await _mount(
        tester,
        TransactionTestRepository(),
        size: const Size(320, 568),
        scale: 1.6,
      );
      expect(find.text('Giao dịch'), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.text('VNPAY-topups'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('VNPAY-topups'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionDetailDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  TransactionTestRepository repo, {
  Size size = const Size(1366, 900),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: SupportTransactionsScreen(repository: repo),
    ),
  );
  await tester.pumpAndSettle();
}
