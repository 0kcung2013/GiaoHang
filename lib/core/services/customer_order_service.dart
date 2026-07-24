import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/order_status_log_model.dart';
import '../models/user_model.dart';
import '../utils/geo_utils.dart';
import '../utils/order_display_utils.dart';
import 'nearest_driver_service.dart';
import 'notification_service.dart';

class CustomerOrderService {
  CustomerOrderService({
    SupabaseClient? client,
    NearestDriverService? nearestDriverService,
    NotificationService? notificationService,
  })  : _supabase = client ?? Supabase.instance.client,
        _nearestDriverService =
            nearestDriverService ?? NearestDriverService(client: client),
        _notificationService =
            notificationService ?? NotificationService(client: client);

  final SupabaseClient _supabase;
  final NearestDriverService _nearestDriverService;
  final NotificationService _notificationService;

  static const String _ordersTable = 'orders';
  static const String _orderItemsTable = 'order_items';
  static const String _orderStatusLogsTable = 'order_status_logs';
  static const String _usersTable = 'users';

  static const String _statusPending = 'pending';
  static const String _statusConfirmed = 'confirmed';
  static const String _statusAssigned = 'assigned';
  static const String _statusPickingUp = 'picking_up';
  static const String _statusDelivering = 'delivering';
  static const String _statusDelivered = 'delivered';
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
    _statusAssigned,   // Cho phép hủy kèm cảnh báo (tài xế đang di chuyển đến)
    _statusPickingUp,  // Cho phép hủy kèm cảnh báo mạnh (tài xế đang ở điểm lấy hàng)
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

  Future<List<OrderModel>> getAvailableOrders({String? driverId}) async {
    try {
      _debugLogOrderQuery(
        'available:start authUser=${_supabase.auth.currentUser?.id ?? 'none'} '
        'statuses=$_statusPending,$_statusConfirmed driver_id=null',
      );
      final response = await _supabase
          .from(_ordersTable)
          .select()
          .inFilter('status', [_statusPending, _statusConfirmed])
          .order('created_at', ascending: false)
          .limit(20);

      var orders = response
          .map(OrderModel.fromJson)
          .where((order) => order.driverId == null || order.driverId!.isEmpty)
          .where((order) {
        if (driverId == null || driverId.isEmpty) return true;
        return !order.rejectedBy.contains(driverId);
      }).toList();

      if (driverId != null && driverId.isNotEmpty) {
        orders = await _nearestDriverService.filterOrdersForNearestDriver(
          orders,
          driverId,
        );
      }

      _debugLogOrders('available:result', orders);
      return orders;
    } catch (error) {
      _debugLogOrderQuery('available:error $error');
      throw Exception('Failed to load available driver orders: $error');
    }
  }

  /// Realtime stream of available orders for a driver.
  /// Chỉ trả về đơn mà [driverId] là tài xế gần điểm lấy hàng nhất.
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
                    (order.driverId == null || order.driverId!.isEmpty),
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

          _debugLogOrders('watch:available', orders);
          return orders;
        });
  }

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

  /// Sau khi tạo đơn: thông báo cho khách + tài xế gần nhất (không auto-assign).
  Future<void> notifyAfterOrderCreated(OrderModel order) async {
    final code = formatOrderCode(order);
    await _notificationService.notifyCustomerOrderCreated(
      customerId: order.customerId,
      orderId: order.id,
      orderCode: code,
    );

    if (order.pickupLat == 0 && order.pickupLng == 0) return;

    final candidates = await _nearestDriverService.loadAssignableDrivers(
      nearLat: order.pickupLat,
      nearLng: order.pickupLng,
    );
    if (candidates.isEmpty) return;

    candidates.sort((a, b) {
      final da = GeoUtils.distanceMeters(
        fromLat: a.lat,
        fromLng: a.lng,
        toLat: order.pickupLat,
        toLng: order.pickupLng,
      );
      final db = GeoUtils.distanceMeters(
        fromLat: b.lat,
        fromLng: b.lng,
        toLat: order.pickupLat,
        toLng: order.pickupLng,
      );
      return da.compareTo(db);
    });

    final nearest = candidates.first;
    final dist = GeoUtils.distanceMeters(
      fromLat: nearest.lat,
      fromLng: nearest.lng,
      toLat: order.pickupLat,
      toLng: order.pickupLng,
    );
    if (dist > NearestDriverService.radiusMeters) return;

    await _notificationService.notifyDriverNewOrder(
      driverUserId: nearest.userId,
      orderId: order.id,
      orderCode: code,
      pickupAddress: shortAddress(order.pickupAddress),
    );
  }

  /// Chuyển đơn cho tài xế khác: thêm [driverUserId] vào rejected_by
  /// để filter nearest bỏ qua tài xế này và hiện đơn cho người gần tiếp theo.
  ///
  /// Trả về user_id tài xế kế tiếp (nếu có trong bán kính), hoặc null.
  Future<String?> transferOrder(String orderId, String driverUserId) async {
    if (orderId.trim().isEmpty || driverUserId.trim().isEmpty) {
      throw Exception('Order id and driver id are required.');
    }

    try {
      await _supabase.rpc('reject_order', params: {
        'p_order_id': orderId,
        'p_driver_user_id': driverUserId,
      });

      final order = await getOrderById(orderId);
      if (order == null) return null;

      final nextDriverId =
          await _nearestDriverService.findNextNearestDriverUserId(
        order: order,
        excludingUserId: driverUserId,
      );

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

  /// Giữ tương thích tên cũ — hành vi giống [transferOrder] (không trả next driver).
  Future<void> rejectOrder(String orderId, String driverUserId) async {
    await transferOrder(orderId, driverUserId);
  }

  Future<List<OrderModel>> getDriverOrders(String driverId) async {
    try {
      _debugLogOrderQuery(
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
      _debugLogOrders('driver:result', orders);
      return orders;
    } catch (error) {
      _debugLogOrderQuery('driver:error $error');
      throw Exception('Failed to load driver orders: $error');
    }
  }

  /// Realtime stream of orders assigned to a specific driver.
  Stream<List<OrderModel>> watchDriverOrders(String driverId) {
    return _supabase
        .from(_ordersTable)
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .map((rows) {
          final orders = rows
              .map(OrderModel.fromJson)
              .where((order) => order.status != _statusCancelled)
              .toList();
          _debugLogOrders('watch:driver', orders);
          return orders;
        });
  }

  /// [customerIdHint] / [orderCodeHint]: lấy từ card đơn (ưu tiên, tránh phụ thuộc re-fetch).
  Future<void> acceptOrder(
    String orderId,
    String driverId, {
    String? customerIdHint,
    String? orderCodeHint,
  }) async {
    if (orderId.trim().isEmpty || driverId.trim().isEmpty) {
      throw Exception('Order id and driver id are required.');
    }

    try {
      final driverRow = await _supabase
          .from('drivers')
          .select('is_available')
          .eq('user_id', driverId)
          .maybeSingle();

      if (driverRow == null) {
        throw Exception('Không tìm thấy hồ sơ tài xế.');
      }

      final isAvailable = driverRow['is_available'] as bool? ?? false;
      if (!isAvailable) {
        throw Exception(
          'Bạn đang offline. Bật trạng thái sẵn sàng để nhận đơn.',
        );
      }

      final activeResponse = await _supabase
          .from(_ordersTable)
          .select('id')
          .eq('driver_id', driverId)
          .inFilter('status', [_statusAssigned, _statusPickingUp, _statusDelivering])
          .maybeSingle();

      if (activeResponse != null) {
        throw Exception(
          'Bạn đang có đơn chưa hoàn thành. Vui lòng giao xong trước khi nhận đơn mới.',
        );
      }

      final acceptedAt = DateTime.now().toIso8601String();
      final response = await _supabase
          .from(_ordersTable)
          .update({
            'driver_id': driverId,
            'status': _statusAssigned,
            'updated_at': acceptedAt,
          })
          .eq('id', orderId)
          .inFilter('status', [_statusPending, _statusConfirmed])
          .isFilter('driver_id', null)
          .select('id, customer_id, tracking_code')
          .maybeSingle();

      if (response == null) {
        throw Exception('Đơn hàng không còn khả dụng.');
      }

      await _createOrderStatusLog(
        orderId: orderId,
        status: _statusAssigned,
        title: 'Đã phân công tài xế',
        description: 'Tài xế đã nhận đơn hàng.',
      );

      // Notify khách — không để lỗi noti làm fail accept.
      final customerId = (customerIdHint != null && customerIdHint.isNotEmpty)
          ? customerIdHint
          : (response['customer_id']?.toString() ?? '');
      final tracking = response['tracking_code']?.toString() ?? '';
      final orderCode =
          (orderCodeHint != null && orderCodeHint.trim().isNotEmpty)
              ? orderCodeHint.trim()
              : (tracking.isNotEmpty
                  ? (tracking.startsWith('GH-') ? tracking : 'GH-$tracking')
                  : 'GH-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}');

      if (customerId.isNotEmpty) {
        try {
          await _notificationService.notifyCustomerOrderAccepted(
            customerId: customerId,
            orderId: orderId,
            orderCode: orderCode,
          );
          if (kDebugMode) {
            debugPrint(
              '[AcceptOrder] notified customer=$customerId order=$orderId code=$orderCode',
            );
          }
        } catch (notifyError) {
          if (kDebugMode) {
            debugPrint('[AcceptOrder] notify customer failed: $notifyError');
          }
        }
      } else if (kDebugMode) {
        debugPrint('[AcceptOrder] missing customer_id on order=$orderId');
      }
    } catch (error) {
      final msg = error.toString().replaceAll('Exception: ', '');
      if (msg.contains('offline') ||
          msg.contains('đơn chưa hoàn thành') ||
          msg.contains('không còn khả dụng') ||
          msg.contains('Không tìm thấy')) {
        throw Exception(msg);
      }
      throw Exception('Failed to accept driver order: $error');
    }
  }

  Future<String> updateDriverOrderStatus({
    required String orderId,
    required String driverId,
    required String currentStatus,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedDriverId = driverId.trim();
    final normalizedCurrentStatus = currentStatus.trim();
    final nextStatus = _nextDriverOrderStatus(normalizedCurrentStatus);

    if (normalizedOrderId.isEmpty || normalizedDriverId.isEmpty) {
      throw Exception('Order id and driver id are required.');
    }
    if (nextStatus == null) {
      throw Exception('This order status cannot be updated by the driver.');
    }
    if (_supabase.auth.currentUser?.id != normalizedDriverId) {
      throw Exception(
        'Only the assigned authenticated driver can update this order.',
      );
    }

    try {
      final updatedAt = DateTime.now().toIso8601String();
      final updatePayload = <String, dynamic>{
        'status': nextStatus,
        'updated_at': updatedAt,
      };
      if (nextStatus == _statusDelivered) {
        updatePayload['actual_delivered_at'] = updatedAt;
      } else if (nextStatus == _statusDelivering) {
        // đã lấy hàng xong → đang giao
        updatePayload['actual_picked_up_at'] = updatedAt;
      }

      final response = await _supabase
          .from(_ordersTable)
          .update(updatePayload)
          .eq('id', normalizedOrderId)
          .eq('driver_id', normalizedDriverId)
          .eq('status', normalizedCurrentStatus)
          .select('id, customer_id, tracking_code')
          .maybeSingle();

      if (response == null) {
        throw Exception(
          'Order status has changed or the order is not assigned to this driver.',
        );
      }

      // total_deliveries: trigger DB `trg_orders_increment_driver_deliveries`
      // (migration 202607220005) tăng khi status → delivered.

      await _createOrderStatusLog(
        orderId: normalizedOrderId,
        status: nextStatus,
        title: _driverStatusLogTitle(nextStatus),
        description: _driverStatusLogDescription(nextStatus),
      );

      final customerId = response['customer_id']?.toString() ?? '';
      final tracking = response['tracking_code']?.toString() ?? '';
      final orderCode = tracking.isNotEmpty
          ? (tracking.startsWith('GH-') ? tracking : 'GH-$tracking')
          : 'GH-${normalizedOrderId.length >= 8 ? normalizedOrderId.substring(0, 8).toUpperCase() : normalizedOrderId}';

      if (customerId.isNotEmpty) {
        try {
          await _notificationService.notifyCustomerOrderStatus(
            customerId: customerId,
            orderId: normalizedOrderId,
            orderCode: orderCode,
            status: nextStatus,
          );
        } catch (notifyError) {
          if (kDebugMode) {
            debugPrint('[UpdateStatus] notify customer failed: $notifyError');
          }
        }
      }

      return nextStatus;
    } catch (error) {
      throw Exception('Failed to update driver order status: $error');
    }
  }

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

      final driverId = order['driver_id']?.toString();
      final tracking = order['tracking_code']?.toString() ?? '';
      final code = tracking.isNotEmpty
          ? (tracking.startsWith('GH-') ? tracking : 'GH-$tracking')
          : 'GH-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}';

      await _supabase
          .from(_ordersTable)
          .update({
            'status': _statusCancelled,
            'status_note': statusNote,
            'cancelled_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('customer_id', customerId)
          .inFilter('status', _cancellableStatuses);

      if (driverId != null && driverId.isNotEmpty) {
        await _notificationService.notifyDriverOrderCancelled(
          driverUserId: driverId,
          orderId: orderId,
          orderCode: code,
        );
      }
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

  String? _nextDriverOrderStatus(String status) {
    return switch (status) {
      _statusAssigned => _statusPickingUp,
      _statusPickingUp => _statusDelivering,
      _statusDelivering => _statusDelivered,
      _ => null,
    };
  }

  String _driverStatusLogTitle(String status) {
    return switch (status) {
      _statusPickingUp => 'Tài xế bắt đầu lấy hàng',
      _statusDelivering => 'Tài xế đã lấy hàng',
      _statusDelivered => 'Đơn hàng đã giao thành công',
      _ => 'Trạng thái đơn hàng đã cập nhật',
    };
  }

  String _driverStatusLogDescription(String status) {
    return switch (status) {
      _statusPickingUp => 'Tài xế đang di chuyển đến điểm lấy hàng.',
      _statusDelivering => 'Tài xế đã nhận hàng và bắt đầu giao.',
      _statusDelivered => 'Tài xế đã hoàn tất giao hàng.',
      _ => 'Trạng thái đơn hàng đã được cập nhật.',
    };
  }

  void _debugLogOrders(String label, List<OrderModel> orders) {
    _debugLogOrderQuery(
      '$label count=${orders.length} '
      'orders=${orders.map((order) => '${order.id}:${order.status}:${order.driverId ?? 'null'}').join(',')}',
    );
  }

  void _debugLogOrderQuery(String message) {
    if (kDebugMode) {
      debugPrint('[DriverOrders] $message');
    }
  }
}
