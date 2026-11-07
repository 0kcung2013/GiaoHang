import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/driver_workload_policy.dart';
import '../models/order_model.dart';
import 'customer_providers.dart';
import 'location_providers.dart';

/// Chọn nhiệm vụ tiếp tục khi đóng map; không lưu hay khôi phục tọa độ riêng.
final driverPriorityOrderIdProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final driverLocationOwnerProvider = Provider.autoDispose
    .family<OrderModel?, String>((ref, userId) {
      final orders = ref.watch(driverOrdersProvider(userId)).valueOrNull;
      final navigation = ref.watch(activeDriverNavigationOrderProvider);
      final priority = ref.watch(driverPriorityOrderIdProvider);
      return DriverWorkloadPolicy.locationOwner(
        orders ?? const [],
        preferredOrderId: navigation ?? priority,
      );
    });
