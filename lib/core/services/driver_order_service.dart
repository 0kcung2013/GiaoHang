import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import '../utils/order_display_utils.dart';
import 'nearest_driver_service.dart';
import 'notification_service.dart';

/// Quản lý danh sách đơn hiển thị cho tài xế và việc chuyển lời mời.
class DriverOrderService {
  DriverOrderService({
    required SupabaseClient client,
    required NearestDriverService nearestDriverService,
    required NotificationService notificationService,
  }) : _supabase = client,
       _nearestDriverService = nearestDriverService,
       _notificationService = notificationService;

  final SupabaseClient _supabase;
  final NearestDriverService _nearestDriverService;
  final NotificationService _notificationService;

  static const String _ordersTable = 'orders';
  static const String _statusPending = 'pending';
  static const String _statusConfirmed = 'confirmed';
  static const String _statusAssigned = 'assigned';
  static const String _statusPickingUp = 'picking_up';
  static const String _statusDelivering = 'delivering';
  static const String _statusDelivered = 'delivered';

  Future<List<OrderModel>> getAvailableOrders({String? driverId}) async {
    try {
      _debugLog(
        'available:start authUser=${_supabase.auth.currentUser?.id ?? 'none'} '
        'statuses=$_statusPending,$_statusConfirmed driver_id=null',
      );
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .inFilter('status', [_statusPending, _statusConfirmed])
          .order('created_at', ascending: false)
          .limit(50);

      var orders = response
          .map(OrderModel.fromJson)
          .where((order) => order.driverId == null || order.driverId!.isEmpty)
          .where((order) => order.isAwaitingDriverAt(DateTime.now()))
          .where((order) {
            if (driverId == null || driverId.isEmpty) return true;
            return !order.rejectedBy.contains(driverId);
          })
          .toList();

      if (driverId != null && driverId.isNotEmpty) {
        orders = await _nearestDriverService.filterOrdersForNearestDriver(
          orders,
          driverId,
        );
      }

      _debugOrders('available:result', orders);
      return orders;
    } catch (error) {
      _debugLog('available:error $error');
      throw Exception('Failed to load available driver orders: $error');
    }
  }

  Stream<List<OrderModel>> watchAvailableOrders({String? driverId}) {
    return _supabase
        .from(_ordersTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50)
        .asyncMap((rows) async {
          var orders = rows
              .map(OrderModel.fromJson)
              .where(
                (order) =>
                    (order.status == _statusPending ||
                        order.status == _statusConfirmed) &&
                    (order.driverId == null || order.driverId!.isEmpty) &&
                    order.isAwaitingDriverAt(DateTime.now()),
              )
              .where((order) {
                if (driverId == null || driverId.isEmpty) return true;
                return !order.rejectedBy.contains(driverId);
              })
              .toList();

          if (driverId != null && driverId.isNotEmpty) {
            orders = await _nearestDriverService.filterOrdersForNearestDriver(
              orders,
              driverId,
            );
          }

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

  Future<void> notifyDriverAfterOrderCreated(OrderModel order) async {
    if (order.pickupLat == 0 && order.pickupLng == 0) return;

    final pendingOffers = await _loadPendingOffersForNotification(order);
    final allocations = await _nearestDriverService.allocateOrderOffers(
      pendingOffers,
    );
    final offeredDriverId = allocations[order.id];
    if (offeredDriverId == null || offeredDriverId.isEmpty) return;

    await _notificationService.notifyDriverNewOrder(
      driverUserId: offeredDriverId,
      orderId: order.id,
      orderCode: formatOrderCode(order),
      pickupAddress: shortAddress(order.pickupAddress),
    );
  }

  Future<String?> transferOrder(String orderId, String driverUserId) async {
    if (orderId.trim().isEmpty || driverUserId.trim().isEmpty) {
      throw Exception('Order id and driver id are required.');
    }

    try {
      await _supabase.rpc(
        'reject_order',
        params: {'p_order_id': orderId, 'p_driver_user_id': driverUserId},
      );

      final order = await _getOrderById(orderId);
      if (order == null) return null;

      final pendingOffers = await getAvailableOrders();
      final allocations = await _nearestDriverService.allocateOrderOffers(
        pendingOffers,
      );
      final nextDriverId = allocations[order.id];

      if (nextDriverId != null && nextDriverId.isNotEmpty) {
        await _notificationService.notifyDriverOrderTransferred(
          driverUserId: nextDriverId,
          orderId: order.id,
          orderCode: formatOrderCode(order),
          pickupAddress: shortAddress(order.pickupAddress),
        );
      }

      return nextDriverId;
    } catch (error) {
      throw Exception('Failed to transfer order: $error');
    }
  }

  Future<List<OrderModel>> _loadPendingOffersForNotification(
    OrderModel createdOrder,
  ) async {
    try {
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .eq('customer_id', createdOrder.customerId)
          .inFilter('status', [_statusPending, _statusConfirmed])
          .order('created_at', ascending: false)
          .limit(50);
      final now = DateTime.now();
      final pending = response
          .map(OrderModel.fromJson)
          .where((order) => order.isAwaitingDriverAt(now))
          .toList();
      if (pending.any((order) => order.id == createdOrder.id)) {
        return pending;
      }
      return [...pending, createdOrder];
    } catch (error) {
      _debugLog('notify:pending-offers error=$error');
      return const [];
    }
  }

  Future<OrderModel?> _getOrderById(String orderId) async {
    final response = await _supabase
        .from(_ordersTable)
        .select()
        .eq('id', orderId)
        .maybeSingle();
    return response == null ? null : OrderModel.fromJson(response);
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
