import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_model.dart';
import '../models/notification_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/order_status_log_model.dart';
import '../models/saved_address_model.dart';
import '../models/user_model.dart';
import '../services/customer_order_service.dart';
import '../services/cargo_image_service.dart';
import '../services/driver_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';
import '../services/review_service.dart';
import '../services/saved_address_service.dart';

final customerOrderServiceProvider = Provider<CustomerOrderService>((ref) {
  return CustomerOrderService();
});

final cargoImageServiceProvider = Provider<CargoImageService>((ref) {
  return CargoImageService();
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

final customerOrdersProvider = FutureProvider.family<List<OrderModel>, String>((
  ref,
  customerId,
) async {
  final service = ref.watch(customerOrderServiceProvider);
  return service.getCustomerOrders(customerId);
});

final customerProfileProvider = FutureProvider.family<UserModel?, String>((
  ref,
  customerId,
) async {
  final service = ref.watch(customerOrderServiceProvider);
  return service.getCustomerProfile(customerId);
});

final recentOrdersProvider = FutureProvider.family<List<OrderModel>, String>((
  ref,
  customerId,
) async {
  final service = ref.watch(customerOrderServiceProvider);
  return service.getRecentOrders(customerId);
});

final activeOrderProvider = FutureProvider.family<OrderModel?, String>((
  ref,
  customerId,
) async {
  final service = ref.watch(customerOrderServiceProvider);
  return service.getActiveOrder(customerId);
});

final availableOrdersProvider = StreamProvider.family<List<OrderModel>, String>((
  ref,
  driverUserId,
) {
  final service = ref.watch(customerOrderServiceProvider);
  return service.watchAvailableOrders(driverId: driverUserId);
});

final driverOrdersProvider = StreamProvider.family<List<OrderModel>, String>((
  ref,
  driverId,
) {
  final service = ref.watch(customerOrderServiceProvider);
  return service.watchDriverOrders(driverId);
});

final orderByIdProvider = FutureProvider.family<OrderModel?, String>((
  ref,
  orderId,
) async {
  final service = ref.watch(customerOrderServiceProvider);
  return service.getOrderById(orderId);
});

final orderByTrackingCodeProvider = FutureProvider.family<OrderModel?, String>((
  ref,
  trackingCode,
) async {
  final service = ref.watch(customerOrderServiceProvider);
  return service.getOrderByTrackingCode(trackingCode);
});

final orderItemsProvider = FutureProvider.family<List<OrderItemModel>, String>((
  ref,
  orderId,
) async {
  final service = ref.watch(customerOrderServiceProvider);
  return service.getOrderItems(orderId);
});

final orderStatusLogsProvider =
    FutureProvider.family<List<OrderStatusLogModel>, String>((
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

final unreadNotificationCountProvider = FutureProvider.family<int, String>((
  ref,
  userId,
) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getUnreadCount(userId);
});

final assignedDriverProvider = FutureProvider.family<DriverModel?, String>((
  ref,
  orderId,
) async {
  final service = ref.watch(driverServiceProvider);
  return service.getDriverForOrder(orderId);
});

final driverByUserIdProvider = FutureProvider.family<DriverModel?, String>((
  ref,
  userId,
) async {
  final service = ref.watch(driverServiceProvider);
  return service.getDriverByUserId(userId);
});

/// Realtime subscription for notifications
final notificationsRealtimeProvider = FutureProvider.family<void, String>((
  ref,
  userId,
) async {
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
final ordersRealtimeProvider = FutureProvider.family<void, String>((
  ref,
  customerId,
) async {
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

typedef TrackedOrderRealtimeRequest = ({String orderId, String trackingCode});

/// Realtime subscription for the currently tracked order.
final trackedOrderRealtimeProvider =
    FutureProvider.family<void, TrackedOrderRealtimeRequest>((
      ref,
      request,
    ) async {
      final realtimeService = ref.watch(realtimeServiceProvider);
      debugPrint(
        '[TrackingRealtime] provider watched '
        'orderId=${request.orderId} trackingCode=${request.trackingCode}',
      );

      realtimeService.subscribeToTrackedOrder(request.orderId, () {
        debugPrint(
          '[TrackingRealtime] invalidating after orders event '
          'trackingCode=${request.trackingCode} orderId=${request.orderId}',
        );
        ref.invalidate(orderByTrackingCodeProvider(request.trackingCode));
        ref.invalidate(orderStatusLogsProvider(request.orderId));
        ref.invalidate(assignedDriverProvider(request.orderId));
        debugPrint(
          '[TrackingRealtime] providers invalidated after orders event',
        );
      });

      realtimeService.subscribeToTrackedOrderStatusLogs(request.orderId, () {
        debugPrint(
          '[TrackingRealtime] invalidating after order_status_logs event '
          'trackingCode=${request.trackingCode} orderId=${request.orderId}',
        );
        ref.invalidate(orderStatusLogsProvider(request.orderId));
        ref.invalidate(orderByTrackingCodeProvider(request.trackingCode));
        debugPrint(
          '[TrackingRealtime] providers invalidated after order_status_logs event',
        );
      });

      ref.onDispose(() async {
        debugPrint(
          '[TrackingRealtime] provider disposed '
          'orderId=${request.orderId} trackingCode=${request.trackingCode}',
        );
        await realtimeService.unsubscribe('tracked_order:${request.orderId}');
        await realtimeService.unsubscribe(
          'tracked_order_status_logs:${request.orderId}',
        );
      });
    });

/// Realtime subscription for cancelled-order dialog on Driver screen.
/// Also refreshes order list providers so the driver sees the update.
final driverCancelledOrderRealtimeProvider =
    FutureProvider.family<void, String>((ref, driverId) async {
  final realtimeService = ref.watch(realtimeServiceProvider);

  realtimeService.subscribeToCancelledOrdersForDriver(
    driverId,
    () async {
      await Future.delayed(const Duration(milliseconds: 800));
      // ignore: unused_result
      ref.refresh(availableOrdersProvider(driverId));
      // ignore: unused_result
      ref.refresh(driverOrdersProvider(driverId));
    },
    onOrderCancelled: (orderId) {
      ref.read(latestCancelledOrderIdProvider.notifier).state = orderId;
    },
  );

  ref.onDispose(() async {
    await realtimeService.unsubscribe('driver_cancelled_orders:$driverId');
  });
});

/// Realtime subscription that refreshes driver order lists on any order change.
final driverOrdersRealtimeProvider =
    FutureProvider.family<void, String>((ref, driverId) async {
  final realtimeService = ref.watch(realtimeServiceProvider);

  realtimeService.subscribeToAllOrdersChanges((payload) async {
    final orderDriverId = payload.newRecord?['driver_id']?.toString();
    final status = payload.newRecord?['status']?.toString();

    // If order was cancelled and was assigned to this driver, skip immediate refresh
    // so the alert dialog has time to pop up and stay visible.
    if (orderDriverId == driverId && status == 'cancelled') {
      debugPrint('[driverOrdersRealtimeProvider] Order cancelled belongs to current driver. Dismiss dialog will handle refresh. Skipping auto-refresh.');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));
    // ignore: unused_result
    ref.refresh(availableOrdersProvider(driverId));
    // ignore: unused_result
    ref.refresh(driverOrdersProvider(driverId));
  });

  ref.onDispose(() async {
    await realtimeService.unsubscribe('driver_all_orders_watch');
  });
});

/// Tracks the latest cancelled order ID — reset after dialog is shown.
final latestCancelledOrderIdProvider = StateProvider<String?>((ref) => null);
