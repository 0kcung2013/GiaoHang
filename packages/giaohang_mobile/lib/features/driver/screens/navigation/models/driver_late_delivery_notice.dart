import 'package:supabase_flutter/supabase_flutter.dart';

class DriverLateDeliveryNotice {
  const DriverLateDeliveryNotice({
    required this.count,
    required this.lockTriggered,
  });
  final int count;
  final bool lockTriggered;
  static const recordedTitle = 'Giao muộn đã ghi nhận';
  static const consumedTitle = 'Đã tính đơn vào khóa giao muộn';

  static DriverLateDeliveryNotice fromLogs(
    List<Map<String, dynamic>> logs,
    DateTime completedAt,
  ) {
    final consumedEarlier = logs
        .where(
          (r) =>
              r['title'] == consumedTitle &&
              DateTime.parse(r['created_at'] as String).isBefore(completedAt),
        )
        .map((r) => r['order_id'])
        .toSet();
    final start = completedAt.subtract(const Duration(hours: 2));
    final count = logs
        .where((r) {
          final time = DateTime.parse(r['created_at'] as String);
          return r['title'] == recordedTitle &&
              !consumedEarlier.contains(r['order_id']) &&
              !time.isBefore(start) &&
              !time.isAfter(completedAt);
        })
        .map((r) => r['order_id'])
        .toSet()
        .length;
    return DriverLateDeliveryNotice(
      count: count,
      lockTriggered: logs.any(
        (r) =>
            r['title'] == consumedTitle &&
            DateTime.parse(
              r['created_at'] as String,
            ).isAtSameMomentAs(completedAt),
      ),
    );
  }
}

class DriverLateDeliveryNoticeRepository {
  DriverLateDeliveryNoticeRepository(this.client);
  final SupabaseClient client;

  Future<DriverLateDeliveryNotice?> forCompletedOrder(String orderId) async {
    final driverId = client.auth.currentUser?.id;
    if (driverId == null) return null;
    final event = await client
        .from('order_status_logs')
        .select('created_at')
        .eq('order_id', orderId)
        .eq('logged_by', driverId)
        .eq('title', DriverLateDeliveryNotice.recordedTitle)
        .maybeSingle();
    if (event == null) return null;
    final completedAt = DateTime.parse(event['created_at'] as String);
    final logs = await client
        .from('order_status_logs')
        .select('order_id,title,created_at')
        .eq('logged_by', driverId)
        .inFilter('title', [
          DriverLateDeliveryNotice.recordedTitle,
          DriverLateDeliveryNotice.consumedTitle,
        ])
        .gte(
          'created_at',
          completedAt.subtract(const Duration(hours: 2)).toIso8601String(),
        )
        .lte('created_at', completedAt.toIso8601String());
    return DriverLateDeliveryNotice.fromLogs(logs, completedAt);
  }
}
