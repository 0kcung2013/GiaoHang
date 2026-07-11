import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Subscribe to a single order row.
  RealtimeChannel subscribeToTrackedOrder(
    String orderId,
    void Function() onOrderChange,
  ) {
    final channelName = 'tracked_order:$orderId';

    _removeChannel(channelName);
    debugPrint(
      '[TrackingRealtime] create orders subscription '
      'channel=$channelName orderId=$orderId filter=id=eq.$orderId',
    );

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) {
            debugPrint(
              '[TrackingRealtime] orders event received '
              'channel=$channelName orderId=$orderId event=${payload.eventType}',
            );
            onOrderChange();
          },
        )
        .subscribe((status, error) {
          debugPrint(
            '[TrackingRealtime] orders subscribe status '
            'channel=$channelName status=$status error=$error',
          );
        });

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to status logs for a single order.
  RealtimeChannel subscribeToTrackedOrderStatusLogs(
    String orderId,
    void Function() onStatusLogChange,
  ) {
    final channelName = 'tracked_order_status_logs:$orderId';

    _removeChannel(channelName);
    debugPrint(
      '[TrackingRealtime] create order_status_logs subscription '
      'channel=$channelName orderId=$orderId filter=order_id=eq.$orderId',
    );

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_status_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) {
            debugPrint(
              '[TrackingRealtime] order_status_logs event received '
              'channel=$channelName orderId=$orderId event=${payload.eventType}',
            );
            onStatusLogChange();
          },
        )
        .subscribe((status, error) {
          debugPrint(
            '[TrackingRealtime] order_status_logs subscribe status '
            'channel=$channelName status=$status error=$error',
          );
        });

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to available-order status changes shown on Driver Home.
  RealtimeChannel subscribeToDriverAvailableOrders(
    String status,
    void Function() onAvailableOrderChange,
  ) {
    final channelName = 'driver_available_orders:$status';

    _removeChannel(channelName);

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: status,
          ),
          callback: (payload) {
            onAvailableOrderChange();
          },
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to cancelled orders for a driver — emits order ID.
  RealtimeChannel subscribeToCancelledOrdersForDriver(
    String driverId,
    void Function() onRefresh, {
    void Function(String orderId)? onOrderCancelled,
  }) {
    final channelName = 'driver_cancelled_orders:$driverId';

    _removeChannel(channelName);
    debugPrint('[RealtimeService] Subscribing to $channelName');

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'cancelled',
          ),
          callback: (payload) {
            debugPrint('[RealtimeService] CANCELLED event received on $channelName: eventType=${payload.eventType}, table=${payload.table}, new=${payload.newRecord}');
            final orderId = payload.newRecord['id']?.toString();
            final orderDriverId = payload.newRecord['driver_id']?.toString();
            debugPrint('[RealtimeService] Parsing orderId=$orderId, orderDriverId=$orderDriverId, targetDriverId=$driverId');
            if (orderId != null && orderId.isNotEmpty && orderDriverId == driverId) {
              debugPrint('[RealtimeService] Triggering onOrderCancelled callback for orderId=$orderId');
              onOrderCancelled?.call(orderId);
            } else {
              // Only auto-refresh if it's not the current driver's assigned order
              onRefresh();
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('[RealtimeService] Channel $channelName status=$status, error=$error');
        });

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to orders assigned to a specific driver user id.
  RealtimeChannel subscribeToDriverAssignedOrders(
    String driverId,
    void Function() onDriverOrderChange,
  ) {
    final channelName = 'driver_assigned_orders:$driverId';

    _removeChannel(channelName);
    debugPrint('[RealtimeService] Subscribing to $channelName');

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) {
            debugPrint('[RealtimeService] ASSIGNED event received on $channelName: eventType=${payload.eventType}, table=${payload.table}, new=${payload.newRecord}');
            onDriverOrderChange();
          },
        )
        .subscribe((status, error) {
          debugPrint('[RealtimeService] Channel $channelName status=$status, error=$error');
        });

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to ALL orders table changes — catch-all for status transitions.
  RealtimeChannel subscribeToAllOrdersChanges(
    void Function(dynamic payload) onAnyChange,
  ) {
    const channelName = 'driver_all_orders_watch';

    _removeChannel(channelName);
    debugPrint('[RealtimeService] Subscribing to $channelName');

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            debugPrint('[RealtimeService] ALL_CHANGES event received on $channelName: eventType=${payload.eventType}, table=${payload.table}, new=${payload.newRecord}');
            onAnyChange(payload);
          },
        )
        .subscribe((status, error) {
          debugPrint('[RealtimeService] Channel $channelName status=$status, error=$error');
        });

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
      debugPrint('[TrackingRealtime] remove channel=$channelName');
      await _supabase.removeChannel(channel);
      _channels.remove(channelName);
    }
  }

  /// Dispose all subscriptions
  Future<void> dispose() async {
    await unsubscribeAll();
  }
}
