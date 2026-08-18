import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import 'driver_order_offer_filter.dart';

/// Quản lý danh sách đơn hiển thị cho tài xế và việc chuyển lời mời.
class DriverOrderService {
  DriverOrderService({required SupabaseClient client}) : _supabase = client;

  final SupabaseClient _supabase;

  static const String _ordersTable = 'orders';
  static const String _statusPending = 'pending';
  static const String _statusConfirmed = 'confirmed';
  static const String _statusAssigned = 'assigned';
  static const String _statusPickingUp = 'picking_up';
  static const String _statusDelivering = 'delivering';
  static const String _statusDelivered = 'delivered';
  static const String _statusReturnApproved = 'return_approved';
  static const String _statusReturning = 'returning';
  static const String _statusReturned = 'returned';

  Future<List<OrderModel>> getAvailableOrders({String? driverId}) async {
    final normalizedDriverId = driverId?.trim() ?? '';
    if (normalizedDriverId.isEmpty) return const [];

    try {
      _debugLog(
        'available:start authUser=${_supabase.auth.currentUser?.id ?? 'none'} '
        'statuses=$_statusPending,$_statusConfirmed driver_id=null',
      );
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .inFilter('status', [_statusPending, _statusConfirmed])
          .eq('offered_driver_id', normalizedDriverId)
          .order('created_at', ascending: false)
          .limit(50);

      final orders = filterPersistedDriverOffers(
        response.map(OrderModel.fromJson),
        driverUserId: normalizedDriverId,
        now: DateTime.now(),
      );

      _debugOrders('available:result', orders);
      return orders;
    } catch (error) {
      _debugLog('available:error $error');
      throw Exception('Failed to load available driver orders: $error');
    }
  }

  Stream<List<OrderModel>> watchAvailableOrders({String? driverId}) {
    final normalizedDriverId = driverId?.trim() ?? '';
    if (normalizedDriverId.isEmpty) {
      return Stream.value(const <OrderModel>[]);
    }

    final realtimeOrders = _supabase
        .from(_ordersTable)
        .stream(primaryKey: ['id'])
        .eq('offered_driver_id', normalizedDriverId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows.map(OrderModel.fromJson).toList());

    return watchPersistedDriverOffers(
      realtimeOrders,
      driverUserId: normalizedDriverId,
    ).map((orders) {
      _debugOrders('watch:available', orders);
      return orders;
    });
  }

  Future<List<OrderModel>> getDriverOrders(String driverId) async {
    try {
      _debugLog(
        'driver:start authUser=${_supabase.auth.currentUser?.id ?? 'none'} '
        'driverId=$driverId statuses='
        '$_statusAssigned,$_statusPickingUp,$_statusDelivering,$_statusDelivered',
      );
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .eq('driver_id', driverId)
          .inFilter('status', [
            _statusAssigned,
            _statusPickingUp,
            _statusDelivering,
            _statusDelivered,
            _statusReturnApproved,
            _statusReturning,
            _statusReturned,
          ])
          .order('created_at', ascending: false);

      final orders = response.map(OrderModel.fromJson).toList();
      _debugOrders('driver:result', orders);
      return orders;
    } catch (error) {
      _debugLog('driver:error $error');
      throw Exception('Failed to load driver orders: $error');
    }
  }

  Stream<List<OrderModel>> watchDriverOrders(String driverId) {
    return _supabase
        .from(_ordersTable)
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .map((rows) {
          final orders = rows
              .map(OrderModel.fromJson)
              .where((order) => order.status != 'cancelled')
              .toList();
          _debugOrders('watch:driver', orders);
          return orders;
        });
  }

  Future<String?> transferOrder(String orderId, String driverUserId) async {
    if (orderId.trim().isEmpty || driverUserId.trim().isEmpty) {
      throw Exception('Order id and driver id are required.');
    }

    try {
      final response = await _supabase.rpc(
        'reject_order',
        params: {'p_order_id': orderId, 'p_driver_user_id': driverUserId},
      );
      final nextDriverId = response?.toString();
      return nextDriverId == null ||
              nextDriverId.isEmpty ||
              nextDriverId == 'null'
          ? null
          : nextDriverId;
    } catch (error) {
      throw Exception('Failed to transfer order: $error');
    }
  }

  void _debugOrders(String label, List<OrderModel> orders) {
    _debugLog(
      '$label count=${orders.length} '
      'orders=${orders.map((order) => '${order.id}:${order.status}:${order.driverId ?? 'null'}').join(',')}',
    );
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[DriverOffers] $message');
    }
  }
}
