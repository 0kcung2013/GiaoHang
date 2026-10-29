import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/admin/constants/admin_strings.dart';
import 'package:operations_web/features/admin/screens/orders/admin_orders_screen.dart';
import 'package:operations_web/features/support_orders/data/support_order_repository.dart';
import 'package:operations_web/features/support_orders/dialogs/support_order_detail_dialog.dart';
import 'package:operations_web/features/support_orders/models/support_order.dart';
import 'package:operations_web/features/support_orders/models/support_order_proof.dart';
import 'helpers/admin_test_fixtures.dart';

void main() {
  setUpAll(loadAdminTestFonts);
  testWidgets(
    'search and status queries are debounced and old responses cannot replace new ones',
    (tester) async {
      final repo = FakeAdminOrders();
      final first = Completer<List<SupportOrder>>();
      final latest = Completer<List<SupportOrder>>();
      final queries = <String>[];
      repo.handler = (query, status, offset) {
        queries.add(query);
        return queries.length == 1 ? first.future : latest.future;
      };
      await tester.pumpWidget(
        adminTestApp(AdminOrdersScreen(repository: repo)),
      );
      await tester.enterText(find.byType(TextField), 'GH-new');
      await tester.pump(const Duration(milliseconds: 400));
      latest.complete([adminOrderFixture(9)]);
      await tester.pumpAndSettle();
      expect(find.text('GH-1029'), findsOneWidget);
      first.complete([adminOrderFixture(1)]);
      await tester.pumpAndSettle();
      expect(find.text('GH-1021'), findsNothing);
      expect(queries, ['', 'GH-new']);
    },
  );
  testWidgets('pagination is real and error can be retried', (tester) async {
    final repo = FakeAdminOrders();
    final offsets = <int>[];
    repo.handler = (query, status, offset) async {
      offsets.add(offset);
      return offset == 0
          ? List.generate(51, (i) => adminOrderFixture(i))
          : [adminOrderFixture(100)];
    };
    await tester.pumpWidget(adminTestApp(AdminOrdersScreen(repository: repo)));
    await tester.pumpAndSettle();
    final next = find.text(AdminStrings.next);
    await tester.scrollUntilVisible(
      next,
      800,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(offsets, [0, 50]);
    expect(find.text('GH-102100'), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find
                .ancestor(
                  of: next,
                  matching: find.byWidgetPredicate(
                    (w) => w is ButtonStyleButton,
                  ),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
    repo.handler = null;
    repo.fail = true;
    final previous = find.text(AdminStrings.previous);
    await tester.scrollUntilVisible(
      previous,
      500,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(find.text(AdminStrings.loadError), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text(AdminStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AdminStrings.loadError), findsNothing);
  });
  testWidgets(
    'order detail reloads the full order and shows existing proof viewer',
    (tester) async {
      final repo = FakeAdminOrders();
      await tester.pumpWidget(
        adminTestApp(
          AdminOrdersScreen(repository: repo, proofRepository: _Proofs()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-order-order-1')));
      await tester.pumpAndSettle();
      expect(repo.details, 1);
      expect(find.byType(SupportOrderDetailDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all supported order states can be selected without losing the search',
    (tester) async {
      final repo = FakeAdminOrders();
      String? status;
      repo.handler = (q, s, o) async {
        status = s;
        return [];
      };
      await tester.pumpWidget(
        adminTestApp(AdminOrdersScreen(repository: repo, initialQuery: 'GH-9')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đang hoàn hàng').last);
      await tester.tap(find.text('Đang hoàn hàng').last);
      await tester.pumpAndSettle();
      expect(status, 'returning');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'GH-9',
      );
    },
  );
}

class _Proofs implements SupportOrderRepository {
  @override
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''}) async =>
      [];
  @override
  Future<List<SupportOrderStatusLog>> fetchStatusLogs(String orderId) async =>
      [];
  @override
  Future<List<SupportOrderProof>> fetchDeliveryProofs(String orderId) async =>
      [];
  @override
  Future<String> resolveDeliveryProofUrl(String storagePath) async =>
      storagePath;
}
