import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../../core/providers/location_providers.dart';
import '../../../../../core/utils/geo_utils.dart';
import '../utils/driver_home_formatters.dart';
import 'availability_toggle_card.dart';
import 'driver_home_banner.dart';
import 'driver_home_layout.dart';
import 'driver_new_order_alert.dart';
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

        final currentPositionAsync = ref.watch(currentPositionProvider);
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
        final activeCount = driverOrders.where(isActiveDriverOrder).length;
        final hasActiveOrder = activeCount > 0;

        final visibleAvailable = driver.isAvailable && !hasActiveOrder
            ? rawAvailableOrders
            : const <OrderModel>[];
        final activeOrders = driverOrders.where(isActiveDriverOrder).toList();
        final showIdleBanner = !hasActiveOrder && visibleAvailable.isEmpty;
        final currentPosition = currentPositionAsync.valueOrNull;
        final pickupDistancesMeters = _pickupDistances(
          orders: [...visibleAvailable, ...activeOrders],
          originLat: currentPosition?.latitude ?? driver.currentLat,
          originLng: currentPosition?.longitude ?? driver.currentLng,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (driver.isAvailable || hasActiveOrder)
              _GpsTracker(driverId: driver.id),
            AvailabilityToggleCard(
              driver: driver,
              hasActiveOrder: hasActiveOrder,
            ),
            SizedBox(height: layout.sectionGap),
            DriverNewOrderAlert(
              orders: visibleAvailable,
              pickupDistancesMeters: pickupDistancesMeters,
            ),
            if (visibleAvailable.isNotEmpty)
              SizedBox(height: layout.sectionGap),
            if (showIdleBanner) ...[
              DriverHomeBanner(isOnline: driver.isAvailable),
              SizedBox(height: layout.sectionGap),
            ],
            DriverQuickStats(
              activeCount: activeCount,
              availableCount: visibleAvailable.length,
            ),
            if (!showIdleBanner) ...[
              SizedBox(height: layout.sectionGap),
              DriverPriorityOrders(
                availableOrders: visibleAvailable,
                driverOrders: driverOrders,
                driverUserId: driver.userId,
                pickupDistancesMeters: pickupDistancesMeters,
              ),
            ],
          ],
        );
      },
    );
  }
}

Map<String, double> _pickupDistances({
  required List<OrderModel> orders,
  required double? originLat,
  required double? originLng,
}) {
  if (originLat == null ||
      originLng == null ||
      (originLat == 0 && originLng == 0)) {
    return const {};
  }

  final distances = <String, double>{};
  for (final order in orders) {
    if (order.pickupLat == 0 && order.pickupLng == 0) continue;
    distances[order.id] = GeoUtils.distanceMeters(
      fromLat: originLat,
      fromLng: originLng,
      toLat: order.pickupLat,
      toLng: order.pickupLng,
    );
  }
  return distances;
}

class _GpsTracker extends ConsumerWidget {
  final String driverId;

  const _GpsTracker({required this.driverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(driverLocationStreamProvider(driverId));
    return const SizedBox.shrink();
  }
}
