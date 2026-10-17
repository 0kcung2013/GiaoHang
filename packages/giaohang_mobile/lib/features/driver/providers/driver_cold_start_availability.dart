import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/customer_providers.dart';

/// Hydrate trạng thái hoạt động từ server mà không thay đổi lựa chọn của tài xế.
final driverColdStartAvailabilityProvider = FutureProvider.family<void, String>(
  (ref, userId) async {
    await ref.watch(driverByUserIdProvider(userId).future);
  },
);
