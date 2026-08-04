import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';

/// Các type notification dùng trong app.
///
/// Phải khớp CHECK constraint `notifications_type_check` trên Supabase:
/// chỉ cho phép: `order_update`, `system`, `promotion`.
class NotificationTypes {
  NotificationTypes._();

  static const orderUpdate = 'order_update';
  static const system = 'system';
  static const promotion = 'promotion';

  // Alias semantic — cùng map về order_update (DB constraint).
  static const orderNew = orderUpdate;
  static const orderAccepted = orderUpdate;
  static const orderTransferred = orderUpdate;
  static const orderStatus = orderUpdate;
  static const orderCancelled = orderUpdate;
}

/// Chính sách phát thông báo: chỉ các mốc người dùng cần biết hoặc cần hành động.
class NotificationDeliveryPolicy {
  NotificationDeliveryPolicy._();

  static const customerOrderMilestones = {
    'picking_up',
    'delivering',
    'delivered',
  };

  static bool shouldNotifyCustomerStatus(String status) =>
      customerOrderMilestones.contains(status.trim());
}

class NotificationService {
  NotificationService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _table = 'notifications';

  Future<List<NotificationModel>> getNotifications(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map(NotificationModel.fromJson).toList();
    } catch (error) {
      throw Exception('Failed to load notifications: $error');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select('id, order_id')
          .eq('user_id', userId)
          .eq('is_read', false);

      final threadKeys = <String>{};
      for (final row in response) {
        final id = row['id']?.toString() ?? '';
        final orderId = row['order_id']?.toString().trim() ?? '';
        threadKeys.add(orderId.isEmpty ? 'notification:$id' : 'order:$orderId');
      }
      return threadKeys.length;
    } catch (error) {
      throw Exception('Failed to load unread notification count: $error');
    }
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    try {
      await _supabase
          .from(_table)
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (error) {
      throw Exception('Failed to mark notification as read: $error');
    }
  }

  Future<void> markNotificationsAsRead(
    List<String> notificationIds,
    String userId,
  ) async {
    final ids = notificationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    try {
      await _supabase
          .from(_table)
          .update({'is_read': true})
          .eq('user_id', userId)
          .inFilter('id', ids);
    } catch (error) {
      throw Exception('Failed to mark notification thread as read: $error');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from(_table)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (error) {
      throw Exception('Failed to mark all notifications as read: $error');
    }
  }

  /// Tạo notification cho [userId].
  /// Throw nếu cả RPC và insert đều fail — caller quyết định nuốt lỗi.
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? orderId,
  }) async {
    final uid = userId.trim();
    final t = title.trim();
    final b = body.trim();
    final ty = type.trim();
    if (uid.isEmpty || t.isEmpty || b.isEmpty || ty.isEmpty) {
      throw Exception('Notification payload invalid.');
    }

    final normalizedOrderId = (orderId != null && orderId.trim().isNotEmpty)
        ? orderId.trim()
        : null;

    Object? lastError;

    try {
      final params = <String, dynamic>{
        'p_user_id': uid,
        'p_title': t,
        'p_body': b,
        'p_type': ty,
      };
      // Chỉ gửi order_id khi có — tránh cast lỗi uuid rỗng.
      if (normalizedOrderId != null) {
        params['p_order_id'] = normalizedOrderId;
      }

      final id = await _supabase.rpc('create_notification', params: params);
      debugPrint(
        '[Notification] RPC ok id=$id user=$uid type=$ty order=$normalizedOrderId',
      );
      return;
    } catch (rpcError) {
      lastError = rpcError;
      debugPrint('[Notification] RPC failed: $rpcError');
    }

    try {
      await _supabase.from(_table).insert({
        'user_id': uid,
        'title': t,
        'body': b,
        'type': ty,
        'is_read': false,
        'order_id': ?normalizedOrderId,
      });
      debugPrint(
        '[Notification] direct insert ok user=$uid type=$ty order=$normalizedOrderId',
      );
      return;
    } catch (error) {
      lastError = error;
      debugPrint('[Notification] direct insert failed: $error');
    }

    throw Exception('Failed to create notification: $lastError');
  }

  Future<void> notifyDriverNewOrder({
    required String driverUserId,
    required String orderId,
    required String orderCode,
    required String pickupAddress,
  }) {
    return createNotification(
      userId: driverUserId,
      title: 'Đơn hàng mới gần bạn',
      body:
          'Đơn $orderCode cần lấy tại $pickupAddress. Mở app để nhận hoặc chuyển đơn.',
      // Hardcode — bắt buộc khớp notifications_type_check
      type: 'order_update',
      orderId: orderId,
    );
  }

  Future<void> notifyCustomerOrderAccepted({
    required String customerId,
    required String orderId,
    required String orderCode,
  }) {
    return createNotification(
      userId: customerId,
      title: 'Tài xế đã nhận đơn',
      body: 'Đơn $orderCode đã có tài xế nhận. Theo dõi tiến trình trên app.',
      type: 'order_update',
      orderId: orderId,
    );
  }

  Future<void> notifyDriverOrderTransferred({
    required String driverUserId,
    required String orderId,
    required String orderCode,
    required String pickupAddress,
  }) {
    return createNotification(
      userId: driverUserId,
      title: 'Đơn được chuyển đến bạn',
      body:
          'Đơn $orderCode (lấy tại $pickupAddress) vừa được chuyển. Hãy nhận đơn nếu bạn sẵn sàng.',
      type: 'order_update',
      orderId: orderId,
    );
  }

  Future<void> notifyCustomerOrderStatus({
    required String customerId,
    required String orderId,
    required String orderCode,
    required String status,
  }) {
    final normalizedStatus = status.trim();
    if (!NotificationDeliveryPolicy.shouldNotifyCustomerStatus(
      normalizedStatus,
    )) {
      return Future.value();
    }

    final (title, body) = _customerStatusCopy(orderCode, normalizedStatus);
    return createNotification(
      userId: customerId,
      title: title,
      body: body,
      type: 'order_update',
      orderId: orderId,
    );
  }

  Future<void> notifyDriverOrderCancelled({
    required String driverUserId,
    required String orderId,
    required String orderCode,
  }) {
    return createNotification(
      userId: driverUserId,
      title: 'Đơn hàng đã bị huỷ',
      body: 'Khách hàng đã huỷ đơn $orderCode.',
      type: 'order_update',
      orderId: orderId,
    );
  }

  Future<void> notifyCustomerOrderCreated({
    required String customerId,
    required String orderId,
    required String orderCode,
  }) {
    // Màn hình tạo đơn thành công đã xác nhận trực tiếp cho khách. Không ghi
    // thêm một sự kiện inbox trùng lặp chỉ để lặp lại cùng thông tin.
    return Future.value();
  }

  (String, String) _customerStatusCopy(String orderCode, String status) {
    return switch (status) {
      'picking_up' => (
        'Tài xế đang đến lấy hàng',
        'Đơn $orderCode: tài xế đang di chuyển đến điểm lấy hàng.',
      ),
      'delivering' => (
        'Đang giao hàng',
        'Đơn $orderCode: tài xế đã lấy hàng và đang giao đến bạn.',
      ),
      'delivered' => (
        'Giao hàng thành công',
        'Đơn $orderCode đã được giao. Cảm ơn bạn đã sử dụng dịch vụ!',
      ),
      _ => throw StateError(
        'Unsupported customer notification status: $status',
      ),
    };
  }
}
