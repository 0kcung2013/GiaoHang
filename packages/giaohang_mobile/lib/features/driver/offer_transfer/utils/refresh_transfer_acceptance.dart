import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cancellation/driver_cancellation_providers.dart';
import '../../cancellation/models/driver_acceptance_state.dart';

/// Chuyển đơn đã thành công; lỗi đọc hạn mức sau đó không biến thành lỗi chuyển.
Future<DriverAcceptanceState?> refreshTransferAcceptance(
  ProviderContainer container,
  String driverUserId,
) async {
  container.invalidate(driverAcceptanceStateProvider(driverUserId));
  try {
    return await container
        .read(driverCancellationRepositoryProvider)
        .getAcceptanceState();
  } catch (_) {
    // Stream acceptance sẽ tiếp tục thử lại và khóa theo giờ server.
    return null;
  }
}
