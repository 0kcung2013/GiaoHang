import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../driver_cancellation_strings.dart';
import '../models/driver_acceptance_state.dart';
import '../models/driver_cancellation_policy.dart';

typedef DriverCancellationRpc =
    Future<dynamic> Function(String name, Map<String, dynamic> params);

class DriverCancellationSnapshot {
  const DriverCancellationSnapshot({required this.policy, required this.clock});
  final DriverCancellationPolicy policy;
  final DriverAcceptanceState clock;
}

class DriverCancellationRepository {
  DriverCancellationRepository({
    SupabaseClient? client,
    DriverCancellationRpc? invoke,
  }) : _client = client,
       _invoke =
           invoke ??
           ((name, params) =>
               (client ?? Supabase.instance.client).rpc(name, params: params));

  final SupabaseClient? _client;
  final DriverCancellationRpc _invoke;

  Future<DriverAcceptanceState> getAcceptanceState() async =>
      DriverAcceptanceState.fromJson(
        _row(await _invoke('get_driver_acceptance_state', {})),
      );

  Future<DriverCancellationSnapshot> getCancellationState(
    String orderId,
  ) async {
    final row = _row(
      await _invoke('get_driver_order_cancellation_state', {
        'p_order_id': orderId,
      }),
    );
    return DriverCancellationSnapshot(
      policy: DriverCancellationPolicy(
        status: row['status'] as String,
        pickupConfirmed: row['pickup_confirmed'] == true,
        pickupArrivedAt: DateTime.tryParse(
          row['pickup_arrived_at']?.toString() ?? '',
        ),
      ),
      clock: DriverAcceptanceState.fromJson(row),
    );
  }

  Future<DateTime> confirmArrival({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final row = _row(
        await _invoke('confirm_driver_pickup_arrival', {
          'p_order_id': orderId,
          'p_lat': latitude,
          'p_lng': longitude,
        }),
      );
      return DateTime.parse(row['pickup_arrived_at'] as String);
    } catch (error) {
      throw DriverCancellationException(_message(error));
    }
  }

  Future<DriverAcceptanceState> cancel(
    String orderId,
    DriverCancellationReason reason,
  ) async {
    try {
      final row = _row(
        await _invoke('cancel_driver_order', {
          'p_order_id': orderId,
          'p_reason': reason == DriverCancellationReason.storeClosed
              ? 'store_closed'
              : 'personal',
        }),
      );
      if (row['order_id'] != orderId ||
          !{
            'pending',
            'confirmed',
            'assigned',
            'picking_up',
            'delivering',
            'delivered',
            'cancelled',
          }.contains(row['new_status'])) {
        throw const DriverCancellationException(
          DriverCancellationStrings.failed,
        );
      }
      return DriverAcceptanceState.fromJson(row);
    } on DriverCancellationException {
      rethrow;
    } catch (error) {
      throw DriverCancellationException(_message(error));
    }
  }

  /// Realtime + polling nhẹ phòng trường hợp mất kênh; chỉ emit khi deadline đổi
  /// hoặc hết hạn, không rebuild màn hình chính mỗi giây.
  Stream<DriverAcceptanceState> watchAcceptanceState(String userId) {
    final client = _client ?? Supabase.instance.client;
    late StreamController<DriverAcceptanceState> controller;
    RealtimeChannel? channel;
    Timer? poll;
    Timer? expiry;
    DriverAcceptanceState? last;
    var loading = false;
    var refreshAgain = false;
    var disposed = false;
    var recoveringFromError = false;
    Future<void> refresh() async {
      if (disposed) return;
      if (loading) {
        refreshAgain = true;
        return;
      }
      loading = true;
      try {
        final state = await getAcceptanceState();
        if (disposed) return;
        if (recoveringFromError ||
            last == null ||
            state.lockedUntil != last!.lockedUntil ||
            state.isLocked != last!.isLocked) {
          controller.add(state);
        }
        recoveringFromError = false;
        last = state;
        expiry?.cancel();
        if (state.isLocked) {
          expiry = Timer(state.lockedUntil!.difference(state.now()), () {
            if (!disposed) {
              controller.add(state);
              unawaited(refresh());
            }
          });
        }
      } catch (error, stack) {
        recoveringFromError = true;
        if (!disposed) controller.addError(error, stack);
      } finally {
        loading = false;
        if (refreshAgain && !disposed) {
          refreshAgain = false;
          unawaited(refresh());
        }
      }
    }

    controller = StreamController<DriverAcceptanceState>(
      onListen: () {
        channel = client
            .channel('driver-acceptance:$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'drivers',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) {
                final deadline = DateTime.tryParse(
                  payload.newRecord['acceptance_locked_until']?.toString() ??
                      '',
                );
                if (last == null || deadline != last!.lockedUntil) {
                  unawaited(refresh());
                }
              },
            )
            .subscribe((status, _) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                unawaited(refresh());
              }
            });
        unawaited(refresh());
        poll = Timer.periodic(
          const Duration(seconds: 30),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () async {
        disposed = true;
        poll?.cancel();
        expiry?.cancel();
        if (channel != null) await client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  static Map<String, dynamic> _row(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const DriverCancellationException(DriverCancellationStrings.failed);
  }

  static String _message(Object error) {
    final text = error.toString();
    if (text.contains('STORE_CANCELLATION_WAIT_REQUIRED')) {
      return DriverCancellationStrings.storeWait;
    }
    if (text.contains('PICKUP_OUTSIDE_GEOFENCE') ||
        text.contains('PICKUP_LOCATION_REQUIRED')) {
      return DriverCancellationStrings.locationRequired;
    }
    if (text.contains('ORDER_ALREADY_PICKED_UP') ||
        text.contains('ORDER_NOT_CANCELLABLE')) {
      return DriverCancellationStrings.unavailable;
    }
    if (text.contains('DRIVER_NOT_ASSIGNED')) {
      return DriverCancellationStrings.orderChanged;
    }
    return DriverCancellationStrings.failed;
  }
}

class DriverCancellationException implements Exception {
  const DriverCancellationException(this.message);
  final String message;
  @override
  String toString() => message;
}
