import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import '../models/order_submission_payload.dart';

typedef CustomerOrderRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

class CustomerOrderCommandService {
  CustomerOrderCommandService({
    SupabaseClient? client,
    CustomerOrderRpcInvoker? rpcInvoker,
  }) : _rpcInvoker =
           rpcInvoker ?? _supabaseInvoker(client ?? Supabase.instance.client);

  final CustomerOrderRpcInvoker _rpcInvoker;

  static const Set<String> _allowedServiceTypes = {
    'standard',
    'express',
    'fragile',
    'document',
  };

  Future<CreatedCustomerOrder> createOrder(OrderModel order) async {
    try {
      final payload = buildOrderSubmissionPayload(
        order.copyWith(serviceType: _normalizeServiceType(order.serviceType)),
      );
      final response = await _rpcInvoker('create_customer_order_v2', {
        'p_order_payload': payload,
      });
      final row = _singleResultRow(response, 'create_customer_order_v2');

      return CreatedCustomerOrder(
        orderId: _requiredString(row, 'order_id'),
        trackingCode: row['tracking_code']?.toString() ?? '',
      );
    } on CustomerOrderCommandException {
      rethrow;
    } catch (error) {
      throw CustomerOrderCommandException(
        'Create-order command failed: $error',
      );
    }
  }

  Future<CancelledCustomerOrder> cancelOrder({
    required String orderId,
    required String customerId,
    String? statusNote,
  }) async {
    try {
      final response = await _rpcInvoker('cancel_customer_order', {
        'p_order_id': orderId,
        'p_customer_id': customerId,
        'p_status_note': statusNote,
      });
      final row = _singleResultRow(response, 'cancel_customer_order');
      final status = _requiredString(row, 'new_status');
      if (status != 'cancelled') {
        throw CustomerOrderCommandException(
          'cancel_customer_order returned unexpected status: $status',
        );
      }

      return CancelledCustomerOrder(
        orderId: _requiredString(row, 'order_id'),
        driverId: _optionalString(row, 'driver_id'),
        trackingCode: row['tracking_code']?.toString() ?? '',
        status: status,
      );
    } on CustomerOrderCommandException {
      rethrow;
    } catch (error) {
      throw CustomerOrderCommandException(
        'Cancel-order command failed: $error',
      );
    }
  }

  static CustomerOrderRpcInvoker _supabaseInvoker(SupabaseClient client) {
    return (functionName, params) async {
      return client.rpc(functionName, params: params);
    };
  }

  static Map<String, dynamic> _singleResultRow(
    dynamic response,
    String commandName,
  ) {
    if (response is List && response.length == 1 && response.single is Map) {
      return Map<String, dynamic>.from(response.single as Map);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw CustomerOrderCommandException(
      '$commandName did not return exactly one result row.',
    );
  }

  static String _requiredString(Map<String, dynamic> row, String field) {
    final value = row[field]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw CustomerOrderCommandException(
        'Atomic order command did not return $field.',
      );
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> row, String field) {
    final value = row[field]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _normalizeServiceType(String value) {
    if (value == 'bulky') return 'fragile';
    return _allowedServiceTypes.contains(value) ? value : 'standard';
  }
}

class CreatedCustomerOrder {
  const CreatedCustomerOrder({
    required this.orderId,
    required this.trackingCode,
  });

  final String orderId;
  final String trackingCode;
}

class CancelledCustomerOrder {
  const CancelledCustomerOrder({
    required this.orderId,
    required this.driverId,
    required this.trackingCode,
    required this.status,
  });

  final String orderId;
  final String? driverId;
  final String trackingCode;
  final String status;
}

class CustomerOrderCommandException implements Exception {
  const CustomerOrderCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
