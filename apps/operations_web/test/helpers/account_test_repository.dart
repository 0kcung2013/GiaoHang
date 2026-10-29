import 'package:operations_web/features/account_controls/data/account_control_repository.dart';
import 'package:operations_web/features/account_controls/models/staff_account.dart';
import 'package:operations_web/features/account_controls/models/account_command.dart';

const accountFixture = StaffAccount(
  id: '00000000-0000-4000-8000-000000000001',
  name: 'Nguyễn Minh An',
  role: 'driver',
  disabled: false,
  activeOrders: 2,
  email: 'an@example.invalid',
  phone: '0900000000',
);
final disabledAccountFixture = StaffAccount(
  id: accountFixture.id,
  name: accountFixture.name,
  role: 'driver',
  disabled: true,
  activeOrders: 0,
  eventId: '00000000-0000-4000-8000-000000000002',
  reason: 'Xác minh vi phạm theo hồ sơ.',
  email: accountFixture.email,
  phone: accountFixture.phone,
  disabledUntil: DateTime.utc(2026, 10, 23),
  actorName: 'Trần Thu Hà',
);

class FakeAccountRepository implements AccountControlRepository {
  List<StaffAccount> rows = [accountFixture];
  List<AccountEvent> events = [];
  final commands = <AccountCommand>[];
  bool fail = false, hasMore = false;
  String search = '';
  String? role;
  int offset = 0, reads = 0;
  bool disabledOnly = false;
  Future<void> Function(AccountCommand)? onApply;
  Future<AccountPage<StaffAccount>> Function()? onList;
  @override
  Future<AccountPage<StaffAccount>> list({
    String search = '',
    String? role,
    bool disabledOnly = false,
    int offset = 0,
  }) async {
    reads++;
    this.search = search;
    this.role = role;
    this.disabledOnly = disabledOnly;
    this.offset = offset;
    if (onList != null) return onList!();
    if (fail) throw Exception('offline');
    return AccountPage(
      rows: rows,
      hasMore: hasMore,
      serverNow: DateTime.utc(2026, 10, 21),
    );
  }

  @override
  Future<AccountPage<AccountEvent>> history(
    String userId, {
    int? before,
  }) async {
    if (fail) throw Exception('offline');
    return AccountPage(
      rows: events,
      hasMore: false,
      serverNow: DateTime.utc(2026, 10, 21),
    );
  }

  @override
  Future<void> apply(AccountCommand command) async {
    commands.add(command);
    await onApply?.call(command);
  }
}
