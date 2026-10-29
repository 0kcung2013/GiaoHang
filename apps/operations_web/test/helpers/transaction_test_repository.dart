import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support_orders/models/support_order.dart';
import 'package:operations_web/features/support_transactions/data/transaction_repository.dart';
import 'package:operations_web/features/support_transactions/models/support_transaction.dart';

SupportTransaction transactionFixture({
  String id = '1',
  String source = 'driver',
  String status = 'completed',
  String kind = 'vnpay_topup',
  DateTime? createdAt,
}) => SupportTransaction(
  id: id,
  source: source,
  kind: kind,
  status: status,
  amount: 200000,
  userId: 'user-1',
  userName: 'Nguyễn Minh An',
  userPhone: '0901234567',
  userRole: 'driver',
  providerRef: 'VNPAY-$id',
  createdAt: createdAt ?? DateTime.utc(2026, 10, 20, 1),
  availableDelta: 200000,
);

class TransactionTestRepository implements TransactionRepository {
  final List<
    ({
      TransactionGroup group,
      String search,
      String status,
      DateTime? from,
      DateTime? to,
      SupportTransaction? before,
    })
  >
  calls = [];
  Future<TransactionPage> Function(
    TransactionGroup group,
    String search,
    SupportTransaction? before,
  )?
  loader;
  bool fail = false, failRequests = false, failCreate = false;
  List<TransactionRequest> requests = [];
  final List<SupportTicketDraft> created = [];
  @override
  Future<TransactionPage> fetch({
    required TransactionGroup group,
    String search = '',
    String status = 'all',
    DateTime? from,
    DateTime? to,
    SupportTransaction? before,
  }) async {
    calls.add((
      group: group,
      search: search,
      status: status,
      from: from,
      to: to,
      before: before,
    ));
    if (fail) throw StateError('Disconnected');
    if (loader != null) return loader!(group, search, before);
    return TransactionPage(
      rows: [transactionFixture(id: group.name)],
      hasMore: false,
      serverNow: DateTime.utc(2026, 10, 20),
    );
  }

  @override
  Future<List<TransactionRequest>> fetchRequests(
    SupportTransaction transaction,
  ) async {
    if (failRequests) throw StateError('Unavailable');
    return requests;
  }

  @override
  Future<void> createRequest(SupportTicketDraft draft) async {
    if (failCreate) throw StateError('Unavailable');
    created.add(draft);
    requests = [
      TransactionRequest(
        id: 'ticket-1',
        subject: draft.subject,
        status: 'open',
      ),
    ];
  }

  @override
  Future<SupportOrder> fetchOrder(String id) async =>
      throw StateError('Order unavailable');
}
