import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../core/providers/customer_providers.dart';
import '../../cancellation/driver_cancellation_providers.dart';
import '../../cancellation/driver_cancellation_strings.dart';
import '../home/driver_home_strings.dart';
import '../home/utils/driver_home_formatters.dart';
import '../home/widgets/availability_toggle_card.dart';

/// Menu chỉ cho đổi trạng thái khi đã tải đủ đơn hiện tại và hạn khóa server.
class DriverDrawerAvailability extends ConsumerWidget {
  const DriverDrawerAvailability({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(driverByUserIdProvider(userId));
    final ordersAsync = ref.watch(driverOrdersProvider(userId));
    final acceptanceAsync = ref.watch(driverAcceptanceStateProvider(userId));
    final hasError =
        driverAsync.hasError ||
        ordersAsync.hasError ||
        acceptanceAsync.hasError;
    final driver = driverAsync.valueOrNull;
    final orders = ordersAsync.valueOrNull;
    final acceptance = acceptanceAsync.valueOrNull;
    if (hasError || driver == null || orders == null || acceptance == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasError
                  ? DriverHomeStrings.coldStartErrorTitle
                  : DriverHomeStrings.coldStartLoading,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (hasError)
              TextButton.icon(
                onPressed: () {
                  ref.invalidate(driverByUserIdProvider(userId));
                  ref.invalidate(driverOrdersProvider(userId));
                  ref.invalidate(driverAcceptanceStateProvider(userId));
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.accent,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(DriverHomeStrings.retryAction),
              ),
          ],
        ),
      );
    }
    return AvailabilityToggleCard(
      driver: driver,
      hasActiveOrder: orders.any(isActiveDriverOrder),
      enabled: driver.isAvailable || !acceptance.isLocked,
      disabledReason: acceptance.isLocked && !driver.isAvailable
          ? DriverCancellationStrings.lockTitle
          : null,
    );
  }
}
