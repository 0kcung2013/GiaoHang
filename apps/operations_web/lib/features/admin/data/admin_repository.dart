import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_snapshot.dart';

abstract interface class AdminRepository {
  Future<AdminSnapshot> fetchSnapshot();
  Future<List<AdminAccount>> fetchAccounts({
    String query = '',
    String? role,
    int offset = 0,
  });
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 50;

  @override
  Future<AdminSnapshot> fetchSnapshot() async {
    final values = <AdminMetric, int?>{};
    // RLS của users/drivers chỉ cho đọc hồ sơ của chính mình.
    // Dùng RPC quản trị hiện có để không nhầm số đếm bị lọc thành tổng hệ thống.
    const restrictedMetrics = {
      AdminMetric.drivers: 'total_drivers',
      AdminMetric.customers: 'total_customers',
      AdminMetric.kyc: 'pending_drivers',
    };
    await Future.wait([
      () async {
        try {
          final result = await client
              .rpc('admin_dashboard_stats')
              .timeout(const Duration(seconds: 15));
          for (final entry in restrictedMetrics.entries) {
            final count = result is Map ? result[entry.value] : null;
            values[entry.key] = count is int && count >= 0 ? count : null;
          }
        } on Exception {
          for (final metric in restrictedMetrics.keys) {
            values[metric] = null;
          }
        }
      }(),
      ...AdminMetric.values
          .where((metric) => !restrictedMetrics.containsKey(metric))
          .map((metric) async {
            try {
              values[metric] = await _count(
                metric,
              ).timeout(const Duration(seconds: 15));
            } on Exception {
              values[metric] = null;
            }
          }),
    ]);
    return AdminSnapshot(
      values: Map.unmodifiable(values),
      updatedAt: DateTime.now(),
    );
  }

  Future<int> _count(AdminMetric metric) async => switch (metric) {
    AdminMetric.orders => await client.from('orders').count(CountOption.exact),
    AdminMetric.waiting =>
      await client
          .from('orders')
          .count(CountOption.exact)
          .inFilter('status', ['pending', 'confirmed'])
          .isFilter('driver_id', null),
    AdminMetric.active =>
      await client.from('orders').count(CountOption.exact).inFilter('status', [
        'assigned',
        'picking_up',
        'delivering',
        'return_approved',
        'returning',
        'risk_hold',
      ]),
    AdminMetric.delivered =>
      await client
          .from('orders')
          .count(CountOption.exact)
          .eq('status', 'delivered'),
    AdminMetric.drivers || AdminMetric.customers || AdminMetric.kyc =>
      throw StateError('Restricted counts require the admin RPC'),
    AdminMetric.changes =>
      await client
          .from('driver_profile_change_requests')
          .count(CountOption.exact)
          .inFilter('status', ['pending', 'applying']),
    AdminMetric.disabledAccounts =>
      (await client.rpc('disabled_account_count')) as int,
  };

  @override
  Future<List<AdminAccount>> fetchAccounts({
    String query = '',
    String? role,
    int offset = 0,
  }) async {
    // Không đọc users trực tiếp: RLS chỉ trả hồ sơ Admin đang đăng nhập.
    final rows = await client
        .rpc(
          'list_admin_accounts',
          params: {
            'p_search': query.trim(),
            'p_role': role,
            'p_offset': offset,
            'p_limit': pageSize + 1,
          },
        )
        .timeout(const Duration(seconds: 15));
    return (rows as List)
        .map(
          (row) => AdminAccount.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }
}
