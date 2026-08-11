import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_contact_message.dart';

abstract interface class OrderContactTransport {
  Future<OrderContactConversation> loadConversation();

  Future<void> connect({
    required void Function(OrderContactMessage message) onMessage,
    required void Function(bool connected) onConnectionChanged,
  });

  Future<OrderContactMessage> send(OrderContactMessage message);

  Future<void> markRead(String messageId);

  Future<void> close();
}

/// Chat theo đơn hàng, lưu trong PostgreSQL và nhận bản ghi mới bằng
/// Supabase Realtime Postgres Changes.
class SupabaseOrderContactTransport implements OrderContactTransport {
  SupabaseOrderContactTransport({
    required SupabaseClient client,
    required this.orderId,
    required this.currentUserId,
  }) : _client = client;

  final SupabaseClient _client;
  final String orderId;
  final String currentUserId;
  RealtimeChannel? _channel;
  Completer<void>? _ready;

  String get _channelName => 'order_messages:$orderId';

  @override
  Future<OrderContactConversation> loadConversation() async {
    final order = await _client
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .single();
    final rows = await _client
        .from('order_messages')
        .select()
        .eq('order_id', orderId)
        .order('created_at')
        .limit(200);
    final messages = List<Map<String, dynamic>>.from(
      rows,
    ).map(OrderContactMessage.fromJson).toList();
    final status = order['status']?.toString() ?? '';
    final canSend = const {
      'assigned',
      'picking_up',
      'delivering',
    }.contains(status);
    final retentionDates =
        messages
            .map((message) => message.expiresAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    return OrderContactConversation(
      messages: messages,
      canSend: canSend,
      retentionEndsAt: retentionDates.isEmpty ? null : retentionDates.last,
    );
  }

  @override
  Future<void> connect({
    required void Function(OrderContactMessage message) onMessage,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    if (_channel != null) return;
    final ready = Completer<void>();
    _ready = ready;

    final channel = _client
        .channel(_channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) {
            try {
              final message = OrderContactMessage.fromJson(payload.newRecord);
              onMessage(message);
            } on FormatException catch (error) {
              debugPrint('[OrderContact] invalid realtime row: $error');
            }
          },
        );
    _channel = channel;
    channel.subscribe((status, error) {
      final connected = status == RealtimeSubscribeStatus.subscribed;
      onConnectionChanged(connected);
      if (connected && !ready.isCompleted) {
        ready.complete();
      } else if ((status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.closed) &&
          !ready.isCompleted) {
        ready.completeError(
          StateError(error?.toString() ?? 'Không thể kết nối kênh chat.'),
        );
      }
    });

    try {
      await ready.future.timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[OrderContact] connect failed channel=$_channelName: $error');
      rethrow;
    }
  }

  @override
  Future<OrderContactMessage> send(OrderContactMessage message) async {
    final channel = _channel;
    final ready = _ready;
    if (channel == null || ready == null) {
      throw StateError('Kênh chat chưa được khởi tạo.');
    }
    await ready.future.timeout(const Duration(seconds: 8));
    final row = await _client
        .from('order_messages')
        .insert(message.toInsertJson())
        .select()
        .single();
    return OrderContactMessage.fromJson(row);
  }

  @override
  Future<void> markRead(String messageId) async {
    await _client.from('order_message_reads').upsert({
      'order_id': orderId,
      'user_id': currentUserId,
      'last_read_message_id': messageId,
      'last_read_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'order_id,user_id');
  }

  @override
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    _ready = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }
}
