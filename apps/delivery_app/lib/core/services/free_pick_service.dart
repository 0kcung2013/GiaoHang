import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import 'notification_service.dart';
import 'order_assignment_service.dart';

typedef FreePickRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

class FreePickViewport {
  const FreePickViewport({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool get isValid =>
      south.isFinite &&
      west.isFinite &&
      north.isFinite &&
      east.isFinite &&
      south >= -90 &&
      north <= 90 &&
      west >= -180 &&
      east <= 180 &&
      south < north &&
      west < east;
}

class FreePickClaimResult {
  const FreePickClaimResult({
    required this.orderId,
    required this.customerId,
    required this.trackingCode,
  });

  final String orderId;
  final String customerId;
  final String trackingCode;
}

class FreePickService {
  FreePickService({
    SupabaseClient? client,
    NotificationService? notificationService,
  }) : _invokeRpc = _defaultRpc(client),
       _notificationService =
           notificationService ?? NotificationService(client: client);

  FreePickService.test({required FreePickRpcInvoker invokeRpc})
    : _invokeRpc = invokeRpc,
      _notificationService = null;

  final FreePickRpcInvoker _invokeRpc;
  final NotificationService? _notificationService;

  Future<List<OrderModel>> getOrdersInViewport(
    FreePickViewport viewport, {
    int limit = 50,
  }) async {
    if (!viewport.isValid) {
      throw const FreePickException('Khung bản đồ không hợp lệ.');
    }
    try {
      final response = await _invokeRpc('get_free_pick_orders_in_view', {
        'p_south': viewport.south,
        'p_west': viewport.west,
        'p_north': viewport.north,
        'p_east': viewport.east,
        'p_limit': limit.clamp(1, 50),
      });
      final rows = response as List<dynamic>? ?? const [];
      return rows
          .whereType<Map>()
          .map((row) => OrderModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      throw FreePickException(_messageFor(error));
    }
  }

  Future<FreePickClaimResult> claimOrder(String orderId) async {
    if (orderId.trim().isEmpty) {
      throw const FreePickException('Thiếu mã đơn hàng.');
    }
    try {
      final response = await _invokeRpc('claim_free_pick_order', {
        'p_order_id': orderId,
      });
      final row = _firstRow(response);
      if (row == null) {
        throw const FreePickException('Đơn hàng không còn khả dụng.');
      }
      final result = FreePickClaimResult(
        orderId: row['order_id']?.toString() ?? orderId,
        customerId: row['customer_id']?.toString() ?? '',
        trackingCode: row['tracking_code']?.toString() ?? '',
      );
      if (result.customerId.isNotEmpty && _notificationService != null) {
        try {
          await _notificationService.notifyCustomerOrderAccepted(
            customerId: result.customerId,
            orderId: result.orderId,
            orderCode: _displayCode(result),
          );
        } catch (_) {
          // Nhận đơn đã hoàn tất trong DB; lỗi thông báo không được rollback.
        }
      }
      return result;
    } catch (error) {
      if (error is FreePickException) rethrow;
      throw FreePickException(_messageFor(error));
    }
  }

  static FreePickRpcInvoker _defaultRpc(SupabaseClient? client) {
    final supabase = client ?? Supabase.instance.client;
    return (name, params) => supabase.rpc(name, params: params);
  }

  static Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return null;
  }

  static String _displayCode(FreePickClaimResult result) {
    if (result.trackingCode.isNotEmpty) {
      return result.trackingCode.startsWith('GH-')
          ? result.trackingCode
          : 'GH-${result.trackingCode}';
    }
    return 'GH-${result.orderId.substring(0, result.orderId.length.clamp(0, 8)).toUpperCase()}';
  }

  static String _messageFor(Object error) {
    final message = error.toString().replaceAll('Exception: ', '');
    if (message.contains('FREE_PICK_VIEWPORT_TOO_LARGE')) {
      return 'Khu vực đang xem quá rộng. Hãy phóng to bản đồ để tìm đơn.';
    }
    if (message.contains('FREE_PICK_ORDER_RESERVED')) {
      return 'Đơn này đang được đề xuất cho tài xế khác.';
    }
    if (message.contains('FREE_PICK_OUT_OF_RANGE')) {
      return 'Đơn nằm ngoài phạm vi FreePick tối đa 50 km.';
    }
    if (message.contains('DRIVER_LOCATION_STALE')) {
      return 'Vị trí GPS đã cũ. Hãy cập nhật vị trí hiện tại rồi thử lại.';
    }
    if (message.contains('DRIVER_HAS_ACTIVE_OFFER')) {
      return 'Bạn đang có một lời mời nhận đơn cần xử lý trước.';
    }
    return OrderAssignmentService.acceptOrderErrorMessage(message);
  }
}

class FreePickException implements Exception {
  const FreePickException(this.message);

  final String message;

  @override
  String toString() => message;
}
