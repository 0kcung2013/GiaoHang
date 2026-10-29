import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/account_controls/constants/customer_dossier_strings.dart';
import 'package:operations_web/features/account_controls/constants/account_strings.dart';
import 'package:operations_web/features/account_controls/data/customer_dossier_repository.dart';
import 'package:operations_web/features/account_controls/dialogs/customer_dossier_dialog.dart';
import 'package:operations_web/features/account_controls/models/staff_account.dart';
import 'package:operations_web/features/account_controls/widgets/customer_dossier_transactions.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support_orders/models/support_order.dart';
import 'package:operations_web/features/support_transactions/models/support_transaction.dart';
import 'helpers/admin_test_fixtures.dart';
import 'helpers/account_test_repository.dart';
import 'helpers/transaction_test_repository.dart';
import 'support_order_proofs_test.dart' show ProofTestRepository;

const customer = StaffAccount(
  id: 'customer-1',
  name: 'Khách hàng thử nghiệm',
  role: 'customer',
  disabled: false,
  activeOrders: 2,
  phone: '0901234567',
  email: 'customer@example.invalid',
);

void main() {
  setUpAll(loadAdminTestFonts);

  testWidgets(
    'customer dossier loads each section only when opened and keeps it when revisiting',
    (tester) async {
      final repository = _Dossier();
      await _pump(tester, repository);
      expect(
        repository.orderReads +
            repository.ticketReads +
            repository.transactionReads,
        0,
      );
      expect(find.text(customer.email!), findsOneWidget);
      await tester.tap(
        find.widgetWithText(ChoiceChip, CustomerDossierStrings.orders),
      );
      await tester.pumpAndSettle();
      expect(repository.orderReads, 1);
      expect(find.text('GH-1021'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(ChoiceChip, CustomerDossierStrings.support),
      );
      await tester.pumpAndSettle();
      expect(repository.ticketReads, 1);
      await tester.tap(
        find.widgetWithText(ChoiceChip, CustomerDossierStrings.orders),
      );
      await tester.pumpAndSettle();
      expect(repository.orderReads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fuzzy financial search never displays a transaction belonging to another user',
    (tester) async {
      final repository = _Dossier();
      await _pump(tester, repository);
      await tester.tap(
        find.widgetWithText(ChoiceChip, CustomerDossierStrings.transactions),
      );
      await tester.pumpAndSettle();
      expect(repository.transactionReads, 1);
      expect(find.textContaining('own-ref'), findsOneWidget);
      expect(find.textContaining('other-ref'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'support can reach existing account decisions but cannot adjust or release them',
    (tester) async {
      await _pump(tester, _Dossier());
      await tester.tap(find.text(CustomerDossierStrings.decisions));
      await tester.pumpAndSettle();
      expect(find.text(AccountStrings.action('disable')), findsOneWidget);
      expect(find.text(AccountStrings.action('adjust')), findsNothing);
      expect(find.text(AccountStrings.action('release')), findsNothing);
    },
  );

  testWidgets(
    'dossier remains usable on a short narrow viewport with large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, _Dossier(), scale: 1.6);
      await tester.tap(
        find.widgetWithText(ChoiceChip, CustomerDossierStrings.orders),
      );
      await tester.pumpAndSettle();
      expect(find.text('GH-1021'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.widgetWithText(ChoiceChip, CustomerDossierStrings.transactions),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('own-ref'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(CustomerDossierTransactions),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.textContaining('own-ref').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Dossier repository, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    adminTestApp(
      CustomerDossierDialog(
        account: customer,
        accountRepository: FakeAccountRepository(),
        isAdmin: false,
        repository: repository,
        orderRepository: ProofTestRepository(),
        transactionRepository: TransactionTestRepository(),
      ),
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
}

class _Dossier implements CustomerDossierRepository {
  int orderReads = 0, ticketReads = 0, transactionReads = 0;
  @override
  Future<List<SupportOrder>> orders(String userId, {int offset = 0}) async {
    expect(userId, customer.id);
    orderReads++;
    return [adminOrderFixture()];
  }

  @override
  Future<SupportOrder> order(String id) async => adminOrderFixture();
  @override
  Future<List<SupportTicket>> tickets(String userId, {int offset = 0}) async {
    expect(userId, customer.id);
    ticketReads++;
    return [];
  }

  @override
  Future<TransactionPage> transactions(
    String userId,
    TransactionGroup group, {
    SupportTransaction? before,
  }) async {
    expect(userId, customer.id);
    transactionReads++;
    return TransactionPage(
      rows: [
        SupportTransaction(
          id: 'own-ref',
          source: 'customer',
          kind: 'delivery_fee_payment',
          status: 'completed',
          amount: 12000,
          userId: customer.id,
          createdAt: DateTime.utc(2026, 10, 22),
        ),
        SupportTransaction(
          id: 'other-ref',
          source: 'customer',
          kind: 'delivery_fee_payment',
          status: 'completed',
          amount: 12000,
          userId: 'other-user',
          createdAt: DateTime.utc(2026, 10, 22),
        ),
      ],
      hasMore: false,
      serverNow: DateTime.utc(2026, 10, 22),
    );
  }
}
