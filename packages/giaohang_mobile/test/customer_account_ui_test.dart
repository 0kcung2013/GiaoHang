import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/models/customer_wallet.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/customer_wallet_providers.dart';
import 'package:giaohang_mobile/features/customer/screens/account/account_screen.dart';
import 'package:giaohang_mobile/features/customer/screens/account/customer_profile_screen.dart';
import 'package:giaohang_mobile/features/customer/screens/account/providers/customer_account_providers.dart';
import 'package:giaohang_mobile/features/customer/screens/account/constants/customer_account_strings.dart';
import 'package:go_router/go_router.dart';
import 'helpers/customer_account_fixtures.dart';
import 'helpers/review_history_fixtures.dart';
import 'helpers/customer_payment_fixtures.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/customer_payment_statistics_screen.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/payment_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/providers/customer_payment_providers.dart';
import 'package:giaohang_mobile/features/reviews/history/customer_review_history_screen.dart';
import 'package:giaohang_mobile/features/reviews/history/providers/review_history_provider.dart';
import 'package:giaohang_mobile/features/reviews/history/review_history_strings.dart';

void main() {
  setUpAll(loadCustomerAccountTestFonts);

  testWidgets(
    'account opens payment statistics and back returns to the account',
    (tester) async {
      await _pump(tester, FakeCustomerAccountRepository());
      await tester.scrollUntilVisible(
        find.text(PaymentStrings.title).hitTestable(),
        200,
      );
      await tester.tap(find.text(PaymentStrings.title));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerPaymentStatisticsScreen), findsOneWidget);
      expect(find.byKey(const Key('payment-total')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
    },
  );

  testWidgets(
    'account opens authored review history and back returns to account',
    (tester) async {
      await _pump(tester, FakeCustomerAccountRepository());
      await tester.scrollUntilVisible(
        find.text(ReviewHistoryStrings.title).hitTestable(),
        200,
      );
      await tester.tap(find.text(ReviewHistoryStrings.title));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerReviewHistoryScreen), findsOneWidget);
      expect(find.text('GH260102700'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerReviewHistoryScreen), findsNothing);
      expect(find.byType(AccountScreen), findsOneWidget);
    },
  );

  testWidgets('a review opens its order using the existing tracking route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/customer-home',
      routes: [
        GoRoute(
          path: '/customer-home',
          builder: (_, state) => state.uri.queryParameters['tab'] == 'tracking'
              ? const Scaffold(body: Text('Reviewed order destination'))
              : const Scaffold(body: AccountScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pump(tester, FakeCustomerAccountRepository(), router: router);
    await tester.scrollUntilVisible(
      find.text(ReviewHistoryStrings.title).hitTestable(),
      200,
    );
    await tester.tap(find.text(ReviewHistoryStrings.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReviewHistoryStrings.order).first);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters, {
      'tab': 'tracking',
      'code': 'GH260102700',
    });
    expect(find.text('Reviewed order destination'), findsOneWidget);
    expect(find.byType(CustomerReviewHistoryScreen), findsNothing);
  });

  testWidgets('a successful profile edit refreshes the account header', (
    tester,
  ) async {
    final repository = FakeCustomerAccountRepository();
    await _pump(tester, repository);
    expect(find.text(customerAccountFixture.fullName), findsOneWidget);
    expect(find.text('Nguyễn Minh Tuấn'), findsNothing);
    await tester.tap(find.byTooltip(CustomerAccountStrings.edit));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, CustomerAccountStrings.save),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, customerAccountFixture.fullName),
      'Tên đã cập nhật',
    );
    await _showSave(tester);
    await tester.tap(find.text(CustomerAccountStrings.save));
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(find.byType(CustomerProfileScreen), findsNothing);
    expect(find.text('Tên đã cập nhật'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a failed save keeps the draft and prevents invalid phone writes',
    (tester) async {
      final repository = FakeCustomerAccountRepository()..fail = true;
      await _pump(tester, repository, edit: true);
      await tester.enterText(
        find.widgetWithText(TextFormField, customerAccountFixture.phone!),
        '123',
      );
      await _showSave(tester);
      await tester.tap(find.text(CustomerAccountStrings.save));
      await tester.pumpAndSettle();
      expect(find.text(CustomerAccountStrings.phoneInvalid), findsOneWidget);
      expect(repository.saves, 0);
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await _showSave(tester);
      await tester.tap(find.text(CustomerAccountStrings.save));
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.text(CustomerAccountStrings.saveError), findsOneWidget);
    },
  );

  testWidgets(
    'leaving an edited profile requires confirmation and Cancel preserves the draft',
    (tester) async {
      await _pump(tester, FakeCustomerAccountRepository(), edit: true);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Thông tin chưa lưu',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(CustomerAccountStrings.leaveTitle), findsOneWidget);
      await tester.tap(find.text(CustomerAccountStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text('Thông tin chưa lưu'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CustomerAccountStrings.leave));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerProfileScreen), findsNothing);
    },
  );

  testWidgets('saving disables repeat submissions until the server responds', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repository = FakeCustomerAccountRepository()
      ..onSave = () => pending.future;
    await _pump(tester, repository, edit: true);
    await tester.enterText(find.byType(TextFormField).first, 'Tên mới');
    await _showSave(tester);
    await tester.tap(find.text(CustomerAccountStrings.save));
    await tester.pump();
    expect(repository.saves, 1);
    expect(find.text(CustomerAccountStrings.saving), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, CustomerAccountStrings.saving),
          )
          .onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
  });

  testWidgets(
    'history action uses the existing orders route with the history view',
    (tester) async {
      final repository = FakeCustomerAccountRepository();
      final router = GoRouter(
        initialLocation: '/customer-home',
        routes: [
          GoRoute(
            path: '/customer-home',
            builder: (_, state) =>
                state.uri.queryParameters['view'] == 'history'
                ? const Scaffold(body: Text('History destination'))
                : const Scaffold(body: AccountScreen()),
          ),
        ],
      );
      addTearDown(router.dispose);
      await _pump(tester, repository, router: router);
      await tester.scrollUntilVisible(
        find.text(CustomerAccountStrings.history),
        250,
      );
      await tester.tap(find.text(CustomerAccountStrings.history));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.queryParameters, {
        'tab': 'orders',
        'view': 'history',
      });
      expect(find.text('History destination'), findsOneWidget);
    },
  );

  testWidgets('profile form fits a short phone with large text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _pump(
      tester,
      FakeCustomerAccountRepository(),
      edit: true,
      scale: 1.6,
    );
    await tester.enterText(find.byType(TextFormField).first, 'Khách hàng mới');
    await _showSave(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text(CustomerAccountStrings.save).hitTestable(),
      findsOneWidget,
    );
  });
}

Future<void> _showSave(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.widgetWithText(FilledButton, CustomerAccountStrings.save),
    150,
    scrollable: find
        .descendant(
          of: find.byType(CustomerProfileScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  FakeCustomerAccountRepository repository, {
  bool edit = false,
  double scale = 1,
  GoRouter? router,
}) async {
  final page = Scaffold(
    body: Builder(
      builder: (context) => edit
          ? TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CustomerProfileScreen(profile: repository.profile),
                ),
              ),
              child: const Text('Edit profile'),
            )
          : const AccountScreen(),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerPaymentRepositoryProvider.overrideWithValue(
          FakeCustomerPaymentRepository(),
        ),
        reviewHistoryRepositoryProvider.overrideWithValue(
          FakeReviewHistoryRepository(),
        ),
        customerAccountUserIdProvider.overrideWithValue(
          customerAccountFixture.id,
        ),
        customerAccountRepositoryProvider.overrideWithValue(repository),
        customerProfileProvider(
          customerAccountFixture.id,
        ).overrideWith((_) async => repository.profile),
        customerWalletSummaryProvider.overrideWith(
          (_) async => const CustomerWalletSummary(
            availableBalance: 0,
            totalReceived: 0,
          ),
        ),
        customerWalletTransactionsProvider.overrideWith((_) async => []),
        customerWalletChangesProvider.overrideWith((_) => const Stream.empty()),
      ],
      child: router == null
          ? MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: page,
            )
          : MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  if (edit) {
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
  }
}
