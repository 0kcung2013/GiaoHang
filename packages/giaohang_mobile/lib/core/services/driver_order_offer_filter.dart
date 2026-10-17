import 'dart:async';

import '../models/order_model.dart';

typedef CancelDriverOfferExpiry = void Function();
typedef DriverOfferExpiryScheduler =
    CancelDriverOfferExpiry Function(Duration delay, void Function() callback);

List<OrderModel> filterPersistedDriverOffers(
  Iterable<OrderModel> orders, {
  required String driverUserId,
  required DateTime now,
}) {
  final normalizedDriverId = driverUserId.trim();
  if (normalizedDriverId.isEmpty) return const [];

  return orders
      .where((order) => order.isOfferedToDriverAt(normalizedDriverId, now))
      .toList();
}

/// Lọc stream Realtime và chủ động phát snapshot mới đúng lúc lời mời hết hạn.
///
/// Supabase có thể không gửi UPDATE cho subscription đã lọc khi một hàng đổi
/// sang [offeredDriverId] khác. Timer cục bộ bảo đảm hàng đang cache vẫn biến
/// mất đúng hạn; cron phía server tiếp tục là nguồn quyết định việc chuyển đơn.
Stream<List<OrderModel>> watchPersistedDriverOffers(
  Stream<List<OrderModel>> source, {
  required String driverUserId,
  DateTime Function()? now,
  DriverOfferExpiryScheduler? scheduleExpiry,
}) {
  final normalizedDriverId = driverUserId.trim();
  if (normalizedDriverId.isEmpty) {
    return Stream.value(const <OrderModel>[]);
  }

  final currentTime = now ?? DateTime.now;
  final expiryScheduler = scheduleExpiry ?? _scheduleDriverOfferExpiry;
  late final StreamController<List<OrderModel>> controller;
  StreamSubscription<List<OrderModel>>? sourceSubscription;
  CancelDriverOfferExpiry? cancelExpiry;
  List<OrderModel> latestOrders = const [];
  var hasSnapshot = false;

  void emitAndScheduleExpiry() {
    cancelExpiry?.call();
    cancelExpiry = null;
    if (!hasSnapshot || controller.isClosed) return;

    final instant = currentTime();
    final visibleOrders = filterPersistedDriverOffers(
      latestOrders,
      driverUserId: normalizedDriverId,
      now: instant,
    );
    controller.add(visibleOrders);

    DateTime? nextDeadline;
    for (final order in visibleOrders) {
      final offerDeadline = order.offerExpiresAt!;
      final deadline = offerDeadline.isBefore(order.assignmentDeadline)
          ? offerDeadline
          : order.assignmentDeadline;
      if (nextDeadline == null || deadline.isBefore(nextDeadline)) {
        nextDeadline = deadline;
      }
    }

    if (nextDeadline != null) {
      cancelExpiry = expiryScheduler(
        nextDeadline.difference(instant),
        emitAndScheduleExpiry,
      );
    }
  }

  controller = StreamController<List<OrderModel>>(
    onListen: () {
      sourceSubscription = source.listen(
        (orders) {
          latestOrders = List.unmodifiable(orders);
          hasSnapshot = true;
          emitAndScheduleExpiry();
        },
        onError: controller.addError,
        onDone: () {
          cancelExpiry?.call();
          controller.close();
        },
      );
    },
    onCancel: () async {
      cancelExpiry?.call();
      await sourceSubscription?.cancel();
    },
  );

  return controller.stream;
}

CancelDriverOfferExpiry _scheduleDriverOfferExpiry(
  Duration delay,
  void Function() callback,
) {
  final timer = Timer(delay, callback);
  return timer.cancel;
}
