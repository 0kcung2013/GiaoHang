import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_domain/giaohang_domain.dart';
import '../models/driver_order_cancellation_event.dart';
import '../models/delivery_proof_model.dart';
import '../models/notification_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/order_status_log_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import '../location/location_ingest_service.dart';
import '../services/customer_order_service.dart';
import '../services/cargo_image_service.dart';
import '../services/delivery_proof_service.dart';
import '../services/driver_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';
import '../services/review_service.dart';

/// Pipeline GPS: throttle → Redis/edge (nếu có) → batch history → Postgres.
final locationIngestServiceProvider = Provider<LocationIngestService>((ref) {
  final service = LocationIngestService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final customerOrderServiceProvider = Provider<CustomerOrderService>((ref) {
  return CustomerOrderService(
    realtimeService: ref.watch(realtimeServiceProvider),
  );
});

final cargoImageServiceProvider = Provider<CargoImageService>((ref) {
  return CargoImageService();
});

final deliveryProofServiceProvider = Provider<DeliveryProofService>((ref) {
  return DeliveryProofService();
});

final orderDeliveryProofsProvider = FutureProvider.autoDispose
    .family<List<DeliveryProofImageModel>, String>((ref, orderId) {
      return ref
          .watch(deliveryProofServiceProvider)
          .getProofsForOrder(orderId: orderId);
    });

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

/// Review khách → tài xế theo orderId (null = chưa đánh giá).
final orderReviewProvider = FutureProvider.family<ReviewModel?, String>((
  ref,
  orderId,
) async {
  final service = ref.watch(reviewServiceProvider);
  return service.getReviewByOrderId(
    orderId,
    direction: ReviewDirection.customerToDriver,
  );
});

/// Review tài xế → khách theo orderId.
final driverCustomerReviewProvider =
    FutureProvider.family<ReviewModel?, String>((ref, orderId) async {
      final service = ref.watch(reviewServiceProvider);
      return service.getReviewByOrderId(
        orderId,
        direction: ReviewDirection.driverToCustomer,
      );
    });

final driverServiceProvider = Provider<DriverService>((ref) {
  return DriverService(
    locationIngest: ref.watch(locationIngestServiceProvider),
  );
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(service.dispose);
  return service;
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

final availableOrdersProvider = StreamProvider.family<List<OrderModel>, String>(
  (ref, driverUserId) {
    final service = ref.watch(customerOrderServiceProvider);
    return service.watchAvailableOrders(driverId: driverUserId);
  },
);

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
        ref.invalidate(orderDeliveryProofsProvider(request.orderId));
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
        ref.invalidate(orderDeliveryProofsProvider(request.orderId));
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

/// Latest relevant cancellation for driver UI consumers.
final driverOrderCancellationEventProvider =
    StateProvider<DriverOrderCancellationEvent?>((ref) => null);

/// Shared cancellation broadcast subscription for the authenticated driver.
final driverCancelledOrderRealtimeProvider =
    FutureProvider.family<void, String>((ref, driverId) async {
      final realtimeService = ref.watch(realtimeServiceProvider);
      String? lastReceivedEventId;

      realtimeService.subscribeToDriverOrderCancellations((event) {
        if (event.eventId == lastReceivedEventId) return;
        lastReceivedEventId = event.eventId;

        final availableOrders =
            ref.read(availableOrdersProvider(driverId)).valueOrNull ??
            const <OrderModel>[];
        final isRelevant = event.isRelevantTo(
          driverUserId: driverId,
          availableOrderIds: {for (final order in availableOrders) order.id},
        );

        ref.invalidate(availableOrdersProvider(driverId));
        ref.invalidate(driverOrdersProvider(driverId));

        if (isRelevant) {
          ref.read(driverOrderCancellationEventProvider.notifier).state = event;
        }
      });

      ref.onDispose(() async {
        await realtimeService.unsubscribe(
          RealtimeService.driverOrderEventsChannel,
        );
      });
    });
