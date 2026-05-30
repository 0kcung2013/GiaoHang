import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage Supabase realtime subscriptions
class RealtimeService {
  RealtimeService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final Map<String, RealtimeChannel> _channels = {};

  /// Subscribe to notifications table for a specific user
  RealtimeChannel subscribeToNotifications(
    String userId,
    void Function() onNotificationChange,
  ) {
    final channelName = 'notifications:$userId';

    // Remove existing channel if any
    _removeChannel(channelName);

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onNotificationChange();
          },
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to orders table for a specific customer
  RealtimeChannel subscribeToOrders(
    String customerId,
    void Function() onOrderChange,
  ) {
    final channelName = 'orders:$customerId';

    // Remove existing channel if any
    _removeChannel(channelName);

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (payload) {
            onOrderChange();
          },
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  /// Unsubscribe from a specific channel
  Future<void> unsubscribe(String channelName) async {
    await _removeChannel(channelName);
  }

  /// Unsubscribe from all channels
  Future<void> unsubscribeAll() async {
    for (final channelName in _channels.keys.toList()) {
      await _removeChannel(channelName);
    }
  }

  Future<void> _removeChannel(String channelName) async {
    final channel = _channels[channelName];
    if (channel != null) {
      await _supabase.removeChannel(channel);
      _channels.remove(channelName);
    }
  }

  /// Dispose all subscriptions
  Future<void> dispose() async {
    await unsubscribeAll();
  }
}