import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

class OrderAssignmentService {
  OrderAssignmentService({
    SupabaseClient? client,
    NotificationService? notificationService,
  }) : _supabase = client ?? Supabase.instance.client,
       _notificationService =
           notificationService ?? NotificationService(client: client);

  final SupabaseClient _supabase;
  final NotificationService _notificationService;

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
      if (_supabase.auth.currentUser?.id != driverId) {
        throw Exception('Chỉ tài xế đang đăng nhập mới có thể nhận đơn.');
      }

      final rpcResponse = await _supabase.rpc(
        'accept_order',
        params: {'p_order_id': orderId},
      );
      final response = _firstRpcRow(rpcResponse);
      if (response == null) {
        throw Exception('Đơn hàng không còn khả dụng.');
      }

      final customerId = (customerIdHint?.isNotEmpty ?? false)
          ? customerIdHint!
          : (response['customer_id']?.toString() ?? '');
      final tracking = response['tracking_code']?.toString() ?? '';
      final orderCode =
          (orderCodeHint != null && orderCodeHint.trim().isNotEmpty)
          ? orderCodeHint.trim()
          : (tracking.isNotEmpty
                ? (tracking.startsWith('GH-') ? tracking : 'GH-$tracking')
                : 'GH-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}');

      if (customerId.isEmpty) {
        if (kDebugMode) {
          debugPrint('[AcceptOrder] missing customer_id on order=$orderId');
        }
        return;
      }

      try {
        await _notificationService.notifyCustomerOrderAccepted(
          customerId: customerId,
          orderId: orderId,
          orderCode: orderCode,
        );
        if (kDebugMode) {
          debugPrint(
            '[AcceptOrder] notified customer=$customerId '
            'order=$orderId code=$orderCode',
          );
        }
      } catch (notifyError) {
        if (kDebugMode) {
          debugPrint('[AcceptOrder] notify customer failed: $notifyError');
        }
      }
    } catch (error) {
      final message = error.toString().replaceAll('Exception: ', '');
      throw Exception(_acceptOrderErrorMessage(message));
    }
  }

  Future<void> markOrderAssignmentTimedOut(String orderId) async {
    try {
      await _supabase.rpc(
        'mark_order_assignment_timed_out',
        params: {'p_order_id': orderId},
      );
    } catch (error) {
      final message = error.toString();
      if (message.contains('ASSIGNMENT_STILL_OPEN')) return;
      throw Exception('Không thể cập nhật thời gian tìm tài xế: $error');
    }
  }

  Future<DateTime> retryOrderAssignment(String orderId) async {
    try {
      final response = await _supabase.rpc(
        'retry_order_assignment',
        params: {'p_order_id': orderId},
      );
      final deadline = DateTime.tryParse(response?.toString() ?? '');
      if (deadline == null) {
        throw Exception('Server did not return an assignment deadline.');
      }
      return deadline;
    } catch (error) {
      final message = error.toString();
      if (message.contains('ASSIGNMENT_STILL_OPEN')) {
        throw Exception('Đơn hàng vẫn đang trong thời gian tìm tài xế.');
      }
      if (message.contains('ORDER_NOT_RETRYABLE')) {
        throw Exception('Đơn hàng đã có tài xế hoặc không thể tìm lại.');
      }
      throw Exception('Không thể tìm lại tài xế: $error');
    }
  }

  Future<String> advanceDriverOrderStatus({
    required String orderId,
    required String driverId,
    required String currentStatus,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedDriverId = driverId.trim();
    final expectedStatus = _nextDriverOrderStatus(currentStatus.trim());

    if (normalizedOrderId.isEmpty || normalizedDriverId.isEmpty) {
      throw Exception('Thiếu mã đơn hàng hoặc mã tài xế.');
    }
    if (expectedStatus == null) {
      throw Exception('Trạng thái hiện tại không thể được tài xế cập nhật.');
    }
    if (_supabase.auth.currentUser?.id != normalizedDriverId) {
      throw Exception('Chỉ tài xế được phân công mới có thể cập nhật đơn.');
    }

    try {
      final rpcResponse = await _supabase.rpc(
        'advance_driver_order_status',
        params: {'p_order_id': normalizedOrderId},
      );
      final response = _firstRpcRow(rpcResponse);
      if (response == null) {
        throw Exception('Đơn hàng đã thay đổi hoặc không còn thuộc tài xế.');
      }

      final nextStatus = response['new_status']?.toString() ?? '';
      if (nextStatus != expectedStatus) {
        throw Exception('Server trả về trạng thái đơn hàng không hợp lệ.');
      }

      final customerId = response['customer_id']?.toString() ?? '';
      final tracking = response['tracking_code']?.toString() ?? '';
      final orderCode = tracking.isNotEmpty
          ? (tracking.startsWith('GH-') ? tracking : 'GH-$tracking')
          : _fallbackOrderCode(normalizedOrderId);

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
      throw Exception(_advanceStatusErrorMessage(error.toString()));
    }
  }

  Map<String, dynamic>? _firstRpcRow(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return null;
  }

  String _acceptOrderErrorMessage(String message) {
    if (message.contains('ASSIGNMENT_EXPIRED')) {
      return 'Đã hết thời gian nhận đơn. '
          'Đơn hàng đang chờ khách tìm lại tài xế.';
    }
    if (message.contains('DRIVER_OFFLINE')) {
      return 'Bạn đang offline. Bật trạng thái sẵn sàng để nhận đơn.';
    }
    if (message.contains('DRIVER_HAS_ACTIVE_ORDER')) {
      return 'Bạn đang có đơn chưa hoàn thành. '
          'Hãy giao xong trước khi nhận đơn mới.';
    }
    if (message.contains('DRIVER_NOT_APPROVED')) {
      return 'Hồ sơ tài xế chưa được phê duyệt.';
    }
    if (message.contains('DRIVER_PROFILE_NOT_FOUND')) {
      return 'Không tìm thấy hồ sơ tài xế.';
    }
    if (message.contains('ORDER_NOT_AVAILABLE')) {
      return 'Đơn hàng không còn khả dụng.';
    }
    if (message.contains('Chỉ tài xế')) return message;
    return 'Không thể nhận đơn hàng: $message';
  }

  String? _nextDriverOrderStatus(String status) {
    return switch (status) {
      'assigned' => 'picking_up',
      'picking_up' => 'delivering',
      'delivering' => 'delivered',
      _ => null,
    };
  }

  String _fallbackOrderCode(String orderId) {
    final shortId = orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId;
    return 'GH-$shortId';
  }

  String _advanceStatusErrorMessage(String message) {
    if (message.contains('PICKUP_PROOF_REQUIRED')) {
      return 'Cần chụp và tải ảnh xác nhận nhận hàng trước khi bắt đầu giao.';
    }
    if (message.contains('DELIVERY_PROOF_REQUIRED')) {
      return 'Cần chụp và tải ảnh bàn giao trước khi hoàn tất đơn hàng.';
    }
    if (message.contains('DRIVER_NOT_ASSIGNED')) {
      return 'Đơn hàng không còn được phân công cho bạn.';
    }
    if (message.contains('INVALID_STATUS_TRANSITION')) {
      return 'Trạng thái đơn hàng vừa thay đổi. Vui lòng tải lại.';
    }
    if (message.contains('ORDER_NOT_FOUND')) {
      return 'Không tìm thấy đơn hàng.';
    }
    if (message.contains('AUTH_REQUIRED')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (message.contains('ORDER_STATUS_CHANGED')) {
      return 'Trạng thái đơn hàng vừa được cập nhật ở thiết bị khác.';
    }
    return 'Không thể cập nhật trạng thái đơn hàng: $message';
  }
}
