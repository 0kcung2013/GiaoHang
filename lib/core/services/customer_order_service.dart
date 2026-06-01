import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/order_status_log_model.dart';
import '../models/user_model.dart';

class CustomerOrderService {
  CustomerOrderService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

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

  Future<List<OrderModel>> getAvailableOrders() async {
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

      final orders = response
          .map(OrderModel.fromJson)
          .where((order) => order.driverId == null || order.driverId!.isEmpty)
          .toList();
      _debugLogOrders('available:result', orders);
      return orders;
    } catch (error) {
      _debugLogOrderQuery('available:error $error');
      throw Exception('Failed to load available driver orders: $error');
    }
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

  Future<void> acceptOrder(String orderId, String driverId) async {
    if (orderId.trim().isEmpty || driverId.trim().isEmpty) {
      throw Exception('Order id and driver id are required.');
    }

    try {
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
          .select('id')
          .maybeSingle();

      if (response == null) {
        throw Exception('Order is no longer available.');
      }

      await _createOrderStatusLog(
        orderId: orderId,
        status: _statusAssigned,
        title: 'Đã phân công tài xế',
        description: 'Tài xế đã nhận đơn hàng.',
      );
    } catch (error) {
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
      final response = await _supabase
          .from(_ordersTable)
          .update({'status': nextStatus, 'updated_at': updatedAt})
          .eq('id', normalizedOrderId)
          .eq('driver_id', normalizedDriverId)
          .eq('status', normalizedCurrentStatus)
          .select('id')
          .maybeSingle();

      if (response == null) {
        throw Exception(
          'Order status has changed or the order is not assigned to this driver.',
        );
      }

      await _createOrderStatusLog(
        orderId: normalizedOrderId,
        status: nextStatus,
        title: _driverStatusLogTitle(nextStatus),
        description: _driverStatusLogDescription(nextStatus),
      );

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
    try {
      final payload = _createOrderPayload(order);

      final response = await _supabase
          .from(_ordersTable)
          .insert(payload)
          .select('id')
          .single();

      final orderId = response['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Created order did not return an id.');
      }

      return orderId;
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
          .select('id,status')
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
