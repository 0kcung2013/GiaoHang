import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_order_cancellation_event.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/order_status_log_model.dart';
import '../models/user_model.dart';
import '../utils/order_display_utils.dart';
import 'driver_order_service.dart';
import 'nearest_driver_service.dart';
import 'notification_service.dart';
import 'order_assignment_service.dart';
import 'realtime_service.dart';

class CustomerOrderService {
  CustomerOrderService({
    SupabaseClient? client,
    NearestDriverService? nearestDriverService,
    NotificationService? notificationService,
    OrderAssignmentService? orderAssignmentService,
    DriverOrderService? driverOrderService,
    RealtimeService? realtimeService,
  }) : _supabase = client ?? Supabase.instance.client,
       _nearestDriverService =
           nearestDriverService ?? NearestDriverService(client: client),
       _notificationService =
           notificationService ?? NotificationService(client: client),
       _orderAssignmentService =
           orderAssignmentService ??
           OrderAssignmentService(
             client: client,
             notificationService: notificationService,
           ),
       _driverOrderService =
           driverOrderService ??
           DriverOrderService(
             client: client ?? Supabase.instance.client,
             nearestDriverService:
                 nearestDriverService ?? NearestDriverService(client: client),
             notificationService:
                 notificationService ?? NotificationService(client: client),
           ),
       _realtimeService = realtimeService ?? RealtimeService(client: client);

  final SupabaseClient _supabase;
  final NearestDriverService _nearestDriverService;
  final NotificationService _notificationService;
  final OrderAssignmentService _orderAssignmentService;
  final DriverOrderService _driverOrderService;
  final RealtimeService _realtimeService;

  static const String _ordersTable = 'orders';
  static const String _orderItemsTable = 'order_items';
  static const String _orderStatusLogsTable = 'order_status_logs';
  static const String _usersTable = 'users';

  static const String _statusPending = 'pending';
  static const String _statusConfirmed = 'confirmed';
  static const String _statusAssigned = 'assigned';
  static const String _statusPickingUp = 'picking_up';
  static const String _statusDelivering = 'delivering';
  static const String _statusCancelled = 'cancelled';
  static const String _serviceStandard = 'standard';
  static const String _serviceExpress = 'express';
  static const String _serviceFragile = 'fragile';
  static const String _serviceDocument = 'document';

  static const Set<String> _allowedServiceTypes = {
    _serviceStandard,
    _serviceExpress,
    _serviceFragile,
    _serviceDocument,
  };

  static const List<String> _activeStatuses = [
    _statusPending,
    _statusConfirmed,
    _statusAssigned,
    _statusPickingUp,
    _statusDelivering,
  ];

  static const List<String> _cancellableStatuses = [
    _statusPending,
    _statusConfirmed,
    _statusAssigned, // Cho phép hủy kèm cảnh báo (tài xế đang di chuyển đến)
    _statusPickingUp, // Cho phép hủy kèm cảnh báo mạnh (tài xế đang ở điểm lấy hàng)
  ];

  Future<List<OrderModel>> getCustomerOrders(String customerId) async {
    try {
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return response.map(OrderModel.fromJson).toList();
    } catch (error) {
      throw Exception('Failed to load customer orders: $error');
    }
  }

  Future<UserModel?> getCustomerProfile(String customerId) async {
    try {
      final response = await _supabase
          .from(_usersTable)
          .select()
          .eq('id', customerId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load customer profile: $error');
    }
  }

  Future<List<OrderModel>> getRecentOrders(
    String customerId, {
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map(OrderModel.fromJson).toList();
    } catch (error) {
      throw Exception('Failed to load recent customer orders: $error');
    }
  }

  Future<OrderModel?> getActiveOrder(String customerId) async {
    try {
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .eq('customer_id', customerId)
          .inFilter('status', _activeStatuses)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return OrderModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load active customer order: $error');
    }
  }

  Future<List<OrderModel>> getAvailableOrders({String? driverId}) =>
      _driverOrderService.getAvailableOrders(driverId: driverId);

  /// Realtime stream of available orders for a driver.
  /// Chỉ trả về đơn mà [driverId] là tài xế gần điểm lấy hàng nhất.
  Stream<List<OrderModel>> watchAvailableOrders({String? driverId}) =>
      _driverOrderService.watchAvailableOrders(driverId: driverId);

  /// Gán đơn cho tài xế gần điểm lấy hàng nhất.
  Future<String?> assignNearestDriver({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    double radiusMeters = NearestDriverService.radiusMeters,
  }) {
    return _nearestDriverService.assignNearestDriver(
      orderId: orderId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      radiusMeters: radiusMeters,
    );
  }

  /// Áp dụng policy thông báo sau khi tạo đơn và báo tài xế gần nhất.
  ///
  /// Xác nhận trùng cho khách được [NotificationService] bỏ qua vì màn hình
  /// tạo đơn thành công đã phản hồi trực tiếp.
  Future<void> notifyAfterOrderCreated(OrderModel order) async {
    final code = formatOrderCode(order);
    await _notificationService.notifyCustomerOrderCreated(
      customerId: order.customerId,
      orderId: order.id,
      orderCode: code,
    );
    await _driverOrderService.notifyDriverAfterOrderCreated(order);
  }

  /// Chuyển đơn cho tài xế khác: thêm [driverUserId] vào rejected_by
  /// để filter nearest bỏ qua tài xế này và hiện đơn cho người gần tiếp theo.
  ///
  /// Trả về user_id tài xế kế tiếp (nếu có trong bán kính), hoặc null.
  Future<String?> transferOrder(String orderId, String driverUserId) =>
      _driverOrderService.transferOrder(orderId, driverUserId);

  /// Giữ tương thích tên cũ — hành vi giống [transferOrder] (không trả next driver).
  Future<void> rejectOrder(String orderId, String driverUserId) async {
    await transferOrder(orderId, driverUserId);
  }

  Future<List<OrderModel>> getDriverOrders(String driverId) =>
      _driverOrderService.getDriverOrders(driverId);

  /// Realtime stream of orders assigned to a specific driver.
  Stream<List<OrderModel>> watchDriverOrders(String driverId) =>
      _driverOrderService.watchDriverOrders(driverId);

  /// [customerIdHint] / [orderCodeHint]: lấy từ card đơn (ưu tiên, tránh phụ thuộc re-fetch).
  Future<void> acceptOrder(
    String orderId,
    String driverId, {
    String? customerIdHint,
    String? orderCodeHint,
  }) => _orderAssignmentService.acceptOrder(
    orderId,
    driverId,
    customerIdHint: customerIdHint,
    orderCodeHint: orderCodeHint,
  );

  Future<void> markOrderAssignmentTimedOut(String orderId) =>
      _orderAssignmentService.markOrderAssignmentTimedOut(orderId);

  Future<DateTime> retryOrderAssignment(String orderId) =>
      _orderAssignmentService.retryOrderAssignment(orderId);

  Future<String> updateDriverOrderStatus({
    required String orderId,
    required String driverId,
    required String currentStatus,
  }) => _orderAssignmentService.advanceDriverOrderStatus(
    orderId: orderId,
    driverId: driverId,
    currentStatus: currentStatus,
  );

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (response == null) return null;
      return OrderModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load order by id: $error');
    }
  }

  Future<OrderModel?> getOrderByTrackingCode(String trackingCode) async {
    final normalizedTrackingCode = trackingCode.trim().replaceFirst(
      RegExp(r'^#'),
      '',
    );
    if (normalizedTrackingCode.isEmpty) return null;

    try {
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .eq('tracking_code', normalizedTrackingCode)
          .maybeSingle();

      if (response == null) return null;
      return OrderModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load order by tracking code: $error');
    }
  }

  Future<String> createOrder(OrderModel order) async {
    final created = await createOrderWithTracking(order);
    return created.orderId;
  }

  /// Tạo đơn + log pending + 1 order_item; trả tracking_code DB (nếu có).
  Future<({String orderId, String trackingCode})> createOrderWithTracking(
    OrderModel order,
  ) async {
    try {
      final payload = _createOrderPayload(order);
      final response = await _supabase
          .from(_ordersTable)
          .insert(payload)
          .select('id, tracking_code')
          .single();

      final orderId = response['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Created order did not return an id.');
      }
      final tracking = response['tracking_code']?.toString() ?? '';

      await _createOrderStatusLog(
        orderId: orderId,
        status: _statusPending,
        title: 'Đã tạo đơn',
        description: 'Đơn hàng đã được ghi nhận và đang chờ tài xế nhận.',
      );

      final itemName = order.itemName?.trim();
      if (itemName != null && itemName.isNotEmpty) {
        try {
          await createOrderItems(orderId, [
            OrderItemModel(
              id: '',
              orderId: orderId,
              name: itemName,
              quantity: 1,
              price: order.deliveryFee,
            ),
          ]);
        } catch (_) {
          // Không chặn tạo đơn nếu order_items fail
        }
      }

      return (orderId: orderId, trackingCode: tracking);
    } catch (error) {
      throw Exception('Failed to create customer order: $error');
    }
  }

  Future<void> createOrderItems(
    String orderId,
    List<OrderItemModel> items,
  ) async {
    if (items.isEmpty) return;

    try {
      final payload = items.map((item) {
        final json = Map<String, dynamic>.from(item.toJson());
        json['order_id'] = orderId;
        _removeEmptyGeneratedId(json);
        return json;
      }).toList();

      await _supabase.from(_orderItemsTable).insert(payload);
    } catch (error) {
      throw Exception('Failed to create order items: $error');
    }
  }

  Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    try {
      final response = await _supabase
          .from(_orderItemsTable)
          .select()
          .eq('order_id', orderId)
          .order('name');

      return response.map(OrderItemModel.fromJson).toList();
    } catch (error) {
      throw Exception('Failed to load order items: $error');
    }
  }

  Future<List<OrderStatusLogModel>> getOrderStatusLogs(String orderId) async {
    try {
      final response = await _supabase
          .from(_orderStatusLogsTable)
          .select()
          .eq('order_id', orderId)
          .order('created_at');

      return response.map(OrderStatusLogModel.fromJson).toList();
    } catch (error) {
      throw Exception('Failed to load order status logs: $error');
    }
  }

  Future<void> _createOrderStatusLog({
    required String orderId,
    required String status,
    required String title,
    required String description,
  }) async {
    try {
      await _supabase.from(_orderStatusLogsTable).insert({
        'order_id': orderId,
        'status': status,
        'title': title,
        'description': description,
      });
    } catch (_) {
      // Status logs are useful for tracking, but accepting the order is the
      // critical operation. Do not fail the assignment if logs are restricted.
    }
  }

  Future<void> cancelOrder(
    String orderId,
    String customerId, {
    String? statusNote,
  }) async {
    try {
      final order = await _supabase
          .from(_ordersTable)
          .select('id,status,driver_id,tracking_code')
          .eq('id', orderId)
          .eq('customer_id', customerId)
          .maybeSingle();

      if (order == null) {
        throw Exception('Order not found for this customer.');
      }

      final status = order['status']?.toString();
      if (!_cancellableStatuses.contains(status)) {
        throw Exception('Only pending or confirmed orders can be cancelled.');
      }

      final tracking = order['tracking_code']?.toString() ?? '';
      final code = tracking.isNotEmpty
          ? (tracking.startsWith('GH-') ? tracking : 'GH-$tracking')
          : 'GH-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}';

      final updatedOrder = await _supabase
          .from(_ordersTable)
          .update({
            'status': _statusCancelled,
            'status_note': statusNote,
            'cancelled_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('customer_id', customerId)
          .inFilter('status', _cancellableStatuses)
          .select('id,status,driver_id,tracking_code')
          .maybeSingle();

      if (updatedOrder == null ||
          updatedOrder['status']?.toString() != _statusCancelled) {
        throw Exception('No cancellable order was updated.');
      }

      final updatedDriverId = updatedOrder['driver_id']?.toString();
      final updatedTracking = updatedOrder['tracking_code']?.toString() ?? '';
      final updatedCode = updatedTracking.isNotEmpty
          ? (updatedTracking.startsWith('GH-')
                ? updatedTracking
                : 'GH-$updatedTracking')
          : code;

      if (updatedDriverId != null && updatedDriverId.isNotEmpty) {
        try {
          await _notificationService.notifyDriverOrderCancelled(
            driverUserId: updatedDriverId,
            orderId: orderId,
            orderCode: updatedCode,
          );
        } catch (_) {
          // The order is already cancelled; persisted notification is
          // best-effort and must not report the committed update as failed.
        }
      }

      await _realtimeService.broadcastOrderCancelled(
        DriverOrderCancellationEvent(
          eventId:
              'order_cancelled:$orderId:'
              '${DateTime.now().microsecondsSinceEpoch}',
          orderId: orderId,
          driverId: updatedDriverId,
          orderCode: updatedCode,
        ),
      );
    } catch (error) {
      throw Exception('Failed to cancel customer order: $error');
    }
  }

  Map<String, dynamic> _createOrderPayload(OrderModel order) {
    final payload = Map<String, dynamic>.from(order.toJson());

    _removeEmptyGeneratedId(payload);
    if ((payload['tracking_code'] as String?)?.isEmpty ?? true) {
      payload.remove('tracking_code');
    }
    if (payload['assignment_expires_at'] == null) {
      payload.remove('assignment_expires_at');
    }
    if (payload['assignment_timed_out_at'] == null) {
      payload.remove('assignment_timed_out_at');
    }
    payload['service_type'] = _normalizeServiceType(
      payload['service_type']?.toString(),
    );

    return payload;
  }

  String _normalizeServiceType(String? value) {
    if (value == 'bulky') return _serviceFragile;
    if (value != null && _allowedServiceTypes.contains(value)) return value;
    return _serviceStandard;
  }

  void _removeEmptyGeneratedId(Map<String, dynamic> json) {
    if ((json['id'] as String?)?.isEmpty ?? true) {
      json.remove('id');
    }
  }
}
