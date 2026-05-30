import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/order_status_log_model.dart';

class CustomerOrderService {
  CustomerOrderService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _ordersTable = 'orders';
  static const String _orderItemsTable = 'order_items';
  static const String _orderStatusLogsTable = 'order_status_logs';

  static const String _statusPending = 'pending';
  static const String _statusConfirmed = 'confirmed';
  static const String _statusAssigned = 'assigned';
  static const String _statusPickingUp = 'picking_up';
  static const String _statusDelivering = 'delivering';
  static const String _statusCancelled = 'cancelled';

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

    return payload;
  }

  void _removeEmptyGeneratedId(Map<String, dynamic> json) {
    if ((json['id'] as String?)?.isEmpty ?? true) {
      json.remove('id');
    }
  }
}