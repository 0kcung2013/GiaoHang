import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support_transactions/data/transaction_controller.dart';
import 'package:operations_web/features/support_transactions/models/support_transaction.dart';
import 'helpers/transaction_test_repository.dart';

void main() {
  test('an old response cannot replace a newly selected group', () async {
    final old = Completer<TransactionPage>();
    final repository = TransactionTestRepository()
      ..loader = (group, search, before) => group == TransactionGroup.topups
          ? old.future
          : Future.value(
              TransactionPage(
                rows: [transactionFixture(id: 'new')],
                hasMore: false,
                serverNow: DateTime.utc(2026),
              ),
            );
    final controller = TransactionController(repository);
    addTearDown(controller.dispose);
    final pending = controller.refresh();
    controller.changeGroup(TransactionGroup.refunds);
    await Future<void>.delayed(Duration.zero);
    old.complete(
      TransactionPage(
        rows: [transactionFixture(id: 'old')],
        hasMore: false,
        serverNow: DateTime.utc(2026),
      ),
    );
    await pending;
    expect(controller.rows.single.id, 'new');
    expect(controller.group, TransactionGroup.refunds);
  });
  test(
    'pagination keeps source-specific identities and supplies the last cursor',
    () async {
      final repo = TransactionTestRepository()
        ..loader = (g, s, b) async => TransactionPage(
          rows: [
            transactionFixture(
              id: 'same',
              source: b == null ? 'driver' : 'customer',
            ),
          ],
          hasMore: b == null,
          serverNow: DateTime.utc(2026),
        );
      final c = TransactionController(repo);
      addTearDown(c.dispose);
      await c.refresh();
      await c.loadMore();
      expect(c.rows.map((r) => r.key), ['driver:same', 'customer:same']);
      expect(repo.calls.last.before?.key, 'driver:same');
      expect(c.hasMore, isFalse);
    },
  );
  test(
    'refresh failure keeps previously loaded rows and can recover',
    () async {
      final repo = TransactionTestRepository();
      final c = TransactionController(repo);
      addTearDown(c.dispose);
      await c.refresh();
      repo.fail = true;
      await c.refresh();
      expect(c.rows, hasLength(1));
      expect(c.error, isNotNull);
      expect(c.loading, isFalse);
      repo.fail = false;
      await c.refresh();
      expect(c.error, isNull);
    },
  );
  test(
    'date filters are passed without changing inclusive/exclusive boundaries',
    () async {
      final repo = TransactionTestRepository();
      final c = TransactionController(repo);
      addTearDown(c.dispose);
      final from = DateTime(2026, 10, 1), to = DateTime(2026, 11, 1);
      c.changeDates(from, to);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls.single.from, from);
      expect(repo.calls.single.to, to);
    },
  );
  test('disposing a request in flight does not notify after dispose', () async {
    final pending = Completer<TransactionPage>();
    final repo = TransactionTestRepository()
      ..loader = (g, s, b) => pending.future;
    final c = TransactionController(repo);
    final load = c.refresh();
    c.dispose();
    pending.complete(
      TransactionPage(rows: [], hasMore: false, serverNow: DateTime.utc(2026)),
    );
    await load;
  });
}
