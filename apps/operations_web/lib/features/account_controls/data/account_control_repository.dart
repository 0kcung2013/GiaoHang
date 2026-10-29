import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_account.dart';
import '../models/account_command.dart';

abstract interface class AccountControlRepository {
  Future<AccountPage<StaffAccount>> list({
    String search = '',
    String? role,
    bool disabledOnly = false,
    int offset = 0,
  });
  Future<AccountPage<AccountEvent>> history(String userId, {int? before});
  Future<void> apply(AccountCommand command);
}

class SupabaseAccountControlRepository implements AccountControlRepository {
  SupabaseAccountControlRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 30;
  static const timeout = Duration(seconds: 15);
  @override
  Future<AccountPage<StaffAccount>> list({
    String search = '',
    String? role,
    bool disabledOnly = false,
    int offset = 0,
  }) async {
    final result = await client
        .rpc(
          'list_staff_accounts',
          params: {
            'p_search': search.trim(),
            'p_role': role,
            'p_disabled_only': disabledOnly,
            'p_offset': offset,
            'p_limit': pageSize,
          },
        )
        .timeout(timeout);
    return _page(result, StaffAccount.fromJson);
  }

  @override
  Future<AccountPage<AccountEvent>> history(
    String userId, {
    int? before,
  }) async => _page(
    await client
        .rpc(
          'account_control_history',
          params: {
            'p_user_id': userId,
            'p_before_seq': before,
            'p_limit': pageSize,
          },
        )
        .timeout(timeout),
    AccountEvent.fromJson,
  );
  @override
  Future<void> apply(AccountCommand command) async {
    final result = await client
        .rpc('set_account_control', params: command.toJson())
        .timeout(timeout);
    // Treat malformed/partial receipts as ambiguous; retry the original request ID.
    if (result is! Map ||
        result['event_id'] is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(result['event_id'] as String) ||
        result['user_id'] != command.userId ||
        result['request_id'] != command.requestId ||
        result['action'] != command.action ||
        result['already_applied'] is! bool ||
        result['server_now'] is! String ||
        DateTime.tryParse(result['server_now'] as String) == null ||
        (command.action != 'release' &&
            command.durationMinutes != null &&
            (result['disabled_until'] is! String ||
                DateTime.tryParse(result['disabled_until'] as String) ==
                    null)) ||
        ((command.action == 'release' || command.durationMinutes == null) &&
            result['disabled_until'] != null)) {
      throw const FormatException('Invalid account decision receipt');
    }
  }

  AccountPage<T> _page<T>(
    dynamic result,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (result is! Map ||
        result['rows'] is! List ||
        result['has_more'] is! bool) {
      throw const FormatException('Invalid account page');
    }
    return AccountPage(
      rows: (result['rows'] as List)
          .map((r) => parse(Map<String, dynamic>.from(r as Map)))
          .toList(growable: false),
      hasMore: result['has_more'] as bool,
      serverNow: DateTime.parse(result['server_now'] as String),
    );
  }
}
