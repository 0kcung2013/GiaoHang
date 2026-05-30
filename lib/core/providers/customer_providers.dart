import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_model.dart';
import '../models/notification_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/order_status_log_model.dart';
import '../models/saved_address_model.dart';
import '../services/customer_order_service.dart';
import '../services/driver_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';
import '../services/review_service.dart';
import '../services/saved_address_service.dart';

final customerOrderServiceProvider = Provider<CustomerOrderService>((ref) {
  return CustomerOrderService();
});

final savedAddressServiceProvider = Provider<SavedAddressService>((ref) {
  return SavedAddressService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

final driverServiceProvider = Provider<DriverService>((ref) {
  return DriverService();
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService();
});

final customerOrdersProvider =
    FutureProvider.family<List<OrderModel>, String>((ref, customerId) async {
      final service = ref.watch(customerOrderServiceProvider);
      return service.getCustomerOrders(customerId);
    });

final recentOrdersProvider =
    FutureProvider.family<List<OrderModel>, String>((ref, customerId) async {
      final service = ref.watch(customerOrderServiceProvider);
      return service.getRecentOrders(customerId);
    });

final activeOrderProvider =
    FutureProvider.family<OrderModel?, String>((ref, customerId) async {
      final service = ref.watch(customerOrderServiceProvider);
      return service.getActiveOrder(customerId);
    });

final orderItemsProvider =
    FutureProvider.family<List<OrderItemModel>, String>((ref, orderId) async {
      final service = ref.watch(customerOrderServiceProvider);
      return service.getOrderItems(orderId);
    });

final orderStatusLogsProvider = FutureProvider.family<List<OrderStatusLogModel>, String>((
  ref,
  orderId,
) async {
  final service = ref.watch(customerOrderServiceProvider);
  return service.getOrderStatusLogs(orderId);
});

final savedAddressesProvider =
    FutureProvider.family<List<SavedAddressModel>, String>((ref, userId) async {
      final service = ref.watch(savedAddressServiceProvider);
      return service.getSavedAddresses(userId);
    });

final notificationsProvider =
    FutureProvider.family<List<NotificationModel>, String>((ref, userId) async {
      final service = ref.watch(notificationServiceProvider);
      return service.getNotifications(userId);
    });

final unreadNotificationCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
      final service = ref.watch(notificationServiceProvider);
      return service.getUnreadCount(userId);
    });

final assignedDriverProvider =
    FutureProvider.family<DriverModel?, String>((ref, orderId) async {
      final service = ref.watch(driverServiceProvider);
      return service.getDriverForOrder(orderId);
    });

/// Realtime subscription for notifications
final notificationsRealtimeProvider =
    FutureProvider.family<void, String>((ref, userId) async {
      final realtimeService = ref.watch(realtimeServiceProvider);
      realtimeService.subscribeToNotifications(userId, () {
        ref.invalidate(notificationsProvider(userId));
        ref.invalidate(unreadNotificationCountProvider(userId));
      });
      ref.onDispose(() async {
        await realtimeService.unsubscribe('notifications:$userId');
      });
    });

/// Realtime subscription for orders
final ordersRealtimeProvider =
    FutureProvider.family<void, String>((ref, customerId) async {
      final realtimeService = ref.watch(realtimeServiceProvider);
      realtimeService.subscribeToOrders(customerId, () {
        ref.invalidate(customerOrdersProvider(customerId));
        ref.invalidate(recentOrdersProvider(customerId));
        ref.invalidate(activeOrderProvider(customerId));
      });
      ref.onDispose(() async {
        await realtimeService.unsubscribe('orders:$customerId');
      });
    });
