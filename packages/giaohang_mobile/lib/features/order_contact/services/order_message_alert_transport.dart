import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_contact_message.dart';

abstract interface class OrderMessageAlertTransport {
  Future<void> connect({
    required void Function(OrderContactMessage message) onMessage,
  });

  Future<void> close();
}

/// Kênh thông báo tin nhắn ở cấp ứng dụng.
///
/// Không lọc `order_id` tại socket vì một khách có thể có nhiều đơn đang hoạt
/// động. RLS của `order_messages` vẫn là lớp giới hạn những bản ghi mà phiên
/// đăng nhập được phép nhận; UI lọc tiếp theo danh sách đơn đang hoạt động.
class SupabaseOrderMessageAlertTransport implements OrderMessageAlertTransport {
  SupabaseOrderMessageAlertTransport({
    required SupabaseClient client,
    required this.currentUserId,
  }) : _client = client;

  final SupabaseClient _client;
  final String currentUserId;
  RealtimeChannel? _channel;

  @override
  Future<void> connect({
    required void Function(OrderContactMessage message) onMessage,
  }) async {
    if (_channel != null) return;

    final ready = Completer<void>();
    final channel = _client
        .channel('order_message_alerts:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_messages',
          callback: (payload) {
            try {
              onMessage(OrderContactMessage.fromJson(payload.newRecord));
            } on FormatException catch (error) {
              debugPrint('[OrderMessageAlert] invalid realtime row: $error');
            }
          },
        );
    _channel = channel;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed && !ready.isCompleted) {
        ready.complete();
      } else if ((status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.timedOut) &&
          !ready.isCompleted) {
        ready.completeError(
          StateError(error?.toString() ?? 'Không thể nhận tin nhắn mới.'),
        );
      }
    });

    await ready.future.timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }
}
