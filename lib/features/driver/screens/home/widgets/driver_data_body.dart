import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../utils/driver_home_formatters.dart';
import 'availability_toggle_card.dart';
import 'driver_home_layout.dart';
import 'driver_priority_orders.dart';
import 'driver_quick_stats.dart';
import 'driver_state_widgets.dart';

/// Simplified dashboard body: toggle + 2 stats + priority orders.
class DriverDashboardBody extends ConsumerWidget {
  final String userId;
  final DriverHomeLayout layout;

  const DriverDashboardBody({
    super.key,
    required this.userId,
    required this.layout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(driverByUserIdProvider(userId));
    final availableOrdersAsync = ref.watch(availableOrdersProvider(userId));

    return driverAsync.when(
      loading: () => const DriverLoadingState(),
      error: (_, _) => DriverErrorState(
        onRetry: () {
          ref.invalidate(driverByUserIdProvider(userId));
          ref.invalidate(availableOrdersProvider(userId));
        },
      ),
      data: (driver) {
        if (driver == null) return const MissingDriverProfileState();

        ref.watch(driverCancelledOrderRealtimeProvider(driver.userId));
        ref.watch(driverOrdersRealtimeProvider(driver.userId));
        final driverOrdersAsync = ref.watch(
          driverOrdersProvider(driver.userId),
        );
        final availableOrdersValue = availableOrdersAsync.valueOrNull;
        final driverOrdersValue = driverOrdersAsync.valueOrNull;
        final isInitialLoading =
            (availableOrdersAsync.isLoading && availableOrdersValue == null) ||
            (driverOrdersAsync.isLoading && driverOrdersValue == null);
        final hasBlockingError =
            (availableOrdersAsync.hasError && availableOrdersValue == null) ||
            (driverOrdersAsync.hasError && driverOrdersValue == null);

        if (isInitialLoading) return const DriverLoadingState();

        if (hasBlockingError) {
          return DriverErrorState(
            onRetry: () {
              ref.invalidate(availableOrdersProvider(userId));
              ref.invalidate(driverOrdersProvider(driver.userId));
            },
          );
        }

        final rawAvailableOrders = availableOrdersValue ?? const <OrderModel>[];
        final driverOrders = driverOrdersValue ?? const <OrderModel>[];
        final activeCount =
            driverOrders.where(isActiveDriverOrder).length;
        final hasActiveOrder = activeCount > 0;

        final visibleAvailable =
            driver.isAvailable && !hasActiveOrder
                ? rawAvailableOrders
                : const <OrderModel>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvailabilityToggleCard(driver: driver),
            SizedBox(height: layout.sectionGap),
            DriverQuickStats(
              activeCount: activeCount,
              availableCount: visibleAvailable.length,
            ),
            SizedBox(height: layout.sectionGap),
            DriverPriorityOrders(
              availableOrders: visibleAvailable,
              driverOrders: driverOrders,
              driverUserId: driver.userId,
            ),
          ],
        );
      },
    );
  }
}
