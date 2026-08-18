import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_order_cancellation_event.dart';

/// Service to manage Supabase realtime subscriptions
class RealtimeService {
  RealtimeService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, Future<bool>> _channelReady = {};

  static const driverOrderEventsChannel = 'driver_order_events';
  static const _orderCancelledEvent = 'order_cancelled';

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

  /// Broadcasts a verified customer cancellation to online driver clients.
  ///
  /// The database update is authoritative, so delivery failure is logged and
  /// deliberately does not escape to the cancellation operation.
  Future<void> broadcastOrderCancelled(
    DriverOrderCancellationEvent event,
  ) async {
    try {
      var channel = _channels[driverOrderEventsChannel];
      var ready = _channelReady[driverOrderEventsChannel];
      if (channel == null) {
        final subscribed = Completer<bool>();
        channel = _supabase.channel(driverOrderEventsChannel);
        _channels[driverOrderEventsChannel] = channel;
        ready = subscribed.future;
        _channelReady[driverOrderEventsChannel] = ready;
        channel.subscribe((status, error) {
          if (subscribed.isCompleted) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            subscribed.complete(true);
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.timedOut) {
            subscribed.complete(false);
          }
        });
      }

      final didSubscribe =
          await ready?.timeout(const Duration(seconds: 5)) ?? true;
      if (!didSubscribe) {
        throw StateError(
          'Cannot subscribe to $driverOrderEventsChannel before broadcast.',
        );
      }

      await channel.sendBroadcastMessage(
        event: _orderCancelledEvent,
        payload: event.toBroadcastPayload(),
      );
    } catch (error) {
      debugPrint(
        '[RealtimeService] broadcastOrderCancelled failed '
        'orderId=${event.orderId}: $error',
      );
    }
  }

  /// Subscribes to the shared driver-order channel and emits valid events.
  RealtimeChannel subscribeToDriverOrderCancellations(
    void Function(DriverOrderCancellationEvent event) onCancelled,
  ) {
    _removeChannel(driverOrderEventsChannel);
    final subscribed = Completer<bool>();

    final channel = _supabase
        .channel(driverOrderEventsChannel)
        .onBroadcast(
          event: _orderCancelledEvent,
          callback: (payload) {
            final wrapped = payload['payload'];
            final raw = wrapped is Map
                ? Map<String, dynamic>.from(wrapped)
                : Map<String, dynamic>.from(payload);
            final event = DriverOrderCancellationEvent.fromBroadcastPayload(
              raw,
            );
            if (event != null) {
              onCancelled(event);
            }
          },
        )
        .subscribe((status, error) {
          if (!subscribed.isCompleted) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              subscribed.complete(true);
            } else if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.timedOut) {
              subscribed.complete(false);
            }
          }
          debugPrint(
            '[RealtimeService] Driver order events status=$status '
            'error=$error',
          );
        });

    _channels[driverOrderEventsChannel] = channel;
    _channelReady[driverOrderEventsChannel] = subscribed.future;
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
            debugPrint(
              '[RealtimeService] ASSIGNED event received on $channelName: eventType=${payload.eventType}, table=${payload.table}, new=${payload.newRecord}',
            );
            onDriverOrderChange();
          },
        )
        .subscribe((status, error) {
          debugPrint(
            '[RealtimeService] Channel $channelName status=$status, error=$error',
          );
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
            debugPrint(
              '[RealtimeService] ALL_CHANGES event received on $channelName: eventType=${payload.eventType}, table=${payload.table}, new=${payload.newRecord}',
            );
            onAnyChange(payload);
          },
        )
        .subscribe((status, error) {
          debugPrint(
            '[RealtimeService] Channel $channelName status=$status, error=$error',
          );
        });

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to driver location updates via drivers table UPDATE.
  /// [onLocationChange] nhận `newRecord` (lat/lng mới) để UI cập nhật ngay,
  /// không phụ thuộc re-fetch có thể stale / loading.
  RealtimeChannel subscribeToDriverLocation(
    String driverId,
    void Function(Map<String, dynamic>? newRecord) onLocationChange,
  ) {
    final channelName = 'driver_location:$driverId';

    _removeChannel(channelName);
    debugPrint('[RealtimeService] Subscribing to $channelName');

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: driverId,
          ),
          callback: (payload) {
            debugPrint(
              '[RealtimeService] DRIVER_LOCATION event received on $channelName',
            );
            final raw = payload.newRecord;
            Map<String, dynamic>? map;
            if (raw.isNotEmpty) {
              map = Map<String, dynamic>.from(raw);
            }
            onLocationChange(map);
          },
        )
        .subscribe((status, error) {
          debugPrint(
            '[RealtimeService] Channel $channelName status=$status, error=$error',
          );
        });

    _channels[channelName] = channel;
    return channel;
  }

  /// Broadcast vị trí TX theo order — khách nhận ngay (không chờ PG).
  Future<void> broadcastDriverLocation({
    required String orderId,
    required double lat,
    required double lng,
  }) async {
    final channelName = 'order_driver_loc:$orderId';
    var channel = _channels[channelName];
    if (channel == null) {
      channel = _supabase.channel(channelName);
      channel.subscribe();
      _channels[channelName] = channel;
    }
    try {
      await channel.sendBroadcastMessage(
        event: 'driver_loc',
        payload: {
          'lat': lat,
          'lng': lng,
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[RealtimeService] broadcastDriverLocation failed: $e');
    }
  }

  /// Khách subscribe broadcast vị trí TX của đơn.
  RealtimeChannel subscribeToOrderDriverBroadcast(
    String orderId,
    void Function(double lat, double lng) onLocation,
  ) {
    final channelName = 'order_driver_loc:$orderId';
    _removeChannel(channelName);
    debugPrint('[RealtimeService] Subscribing broadcast $channelName');

    final channel = _supabase
        .channel(channelName)
        .onBroadcast(
          event: 'driver_loc',
          callback: (payload) {
            // payload có thể bọc { event, payload: { lat, lng } } tùy version
            final data = payload['payload'] is Map
                ? Map<String, dynamic>.from(payload['payload'] as Map)
                : payload;
            final lat = _asDouble(data['lat']);
            final lng = _asDouble(data['lng']);
            if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
              onLocation(lat, lng);
            }
          },
        )
        .subscribe((status, error) {
          debugPrint(
            '[RealtimeService] Broadcast $channelName status=$status err=$error',
          );
        });

    _channels[channelName] = channel;
    return channel;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
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
      _channelReady.remove(channelName);
    }
  }

  /// Dispose all subscriptions
  Future<void> dispose() async {
    await unsubscribeAll();
  }
}
