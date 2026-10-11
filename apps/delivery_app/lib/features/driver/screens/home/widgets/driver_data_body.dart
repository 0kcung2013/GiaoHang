import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../../core/providers/location_providers.dart';
import '../providers/driver_order_route_distance_provider.dart';
import '../utils/driver_dashboard_location.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_home_banner.dart';
import 'driver_home_layout.dart';
import 'driver_new_order_alert.dart';
import 'driver_priority_orders.dart';
import 'driver_quick_stats.dart';
import 'driver_state_widgets.dart';
import '../../../cancellation/driver_cancellation_providers.dart';
import '../../../cancellation/driver_cancellation_strings.dart';
import '../../../cancellation/widgets/driver_acceptance_lock_card.dart';
import '../../../offer_transfer/models/driver_offer_transfer_state.dart';
import '../../../offer_transfer/driver_offer_transfer_strings.dart';

/// Dashboard: thời gian khóa, thống kê và các đơn ưu tiên.
class DriverDashboardBody extends ConsumerWidget {
  final String userId;
  final String? email;
  final DriverHomeLayout layout;

  const DriverDashboardBody({
    super.key,
    required this.userId,
    required this.email,
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
        final acceptanceAsync = ref.watch(
          driverAcceptanceStateProvider(userId),
        );
        final acceptance = acceptanceAsync.valueOrNull;
        if (acceptance == null) {
          if (acceptanceAsync.hasError) {
            return DriverErrorState(
              onRetry: () =>
                  ref.invalidate(driverAcceptanceStateProvider(userId)),
            );
          }
          return const DriverLoadingState();
        }
        final acceptanceLocked = acceptance.isLocked;

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

        final visibleAvailable =
            driver.isAvailable && !hasActiveOrder && !acceptanceLocked
            ? rawAvailableOrders
            : const <OrderModel>[];
        final activeOrders = driverOrders.where(isActiveDriverOrder).toList();
        final showIdleBanner = !hasActiveOrder && visibleAvailable.isEmpty;
        final currentPosition = currentPositionAsync.valueOrNull;
        final locationMode = ref.watch(driverLocationModeProvider);
        final dashboardPosition = resolveDriverDashboardPosition(
          locationMode: locationMode,
          email: email,
          rawLat: currentPosition?.latitude,
          rawLng: currentPosition?.longitude,
          storedLat: driver.currentLat,
          storedLng: driver.currentLng,
        );
        final offerPosition = resolveDriverOfferPosition(
          dashboardPosition: dashboardPosition,
          storedLat: driver.currentLat,
          storedLng: driver.currentLng,
        );
        final pickupDistancesMeters = <String, double>{
          ..._pickupDistances(
            ref: ref,
            orders: visibleAvailable,
            driverId: driver.userId,
            driverPosition: offerPosition,
          ),
          ..._pickupDistances(
            ref: ref,
            orders: activeOrders,
            driverId: driver.userId,
            driverPosition: dashboardPosition,
          ),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (driver.isAvailable || hasActiveOrder)
              _GpsTracker(driverId: driver.id),
            if (acceptanceLocked) ...[
              DriverAcceptanceLockCard(
                lockedUntil: acceptance.lockedUntil!,
                now: acceptance.now,
                description:
                    acceptance.lockReason == DriverOfferTransferState.lockReason
                    ? DriverOfferTransferStrings.lockDescription
                    : DriverCancellationStrings.lockDescription,
                onExpired: () {
                  ref.invalidate(driverAcceptanceStateProvider(userId));
                  ref.invalidate(availableOrdersProvider(userId));
                },
              ),
              SizedBox(height: layout.sectionGap),
            ],
            DriverNewOrderAlert(
              orders: visibleAvailable,
              pickupDistancesMeters: pickupDistancesMeters,
            ),
            if (visibleAvailable.isNotEmpty)
              SizedBox(height: layout.sectionGap),
            if (showIdleBanner && !acceptanceLocked) ...[
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
                driverPosition: offerPosition,
              ),
            ],
          ],
        );
      },
    );
  }
}

Map<String, double> _pickupDistances({
  required WidgetRef ref,
  required List<OrderModel> orders,
  required String driverId,
  required LatLng? driverPosition,
}) {
  final distances = <String, double>{};
  for (final order in orders) {
    final request = driverOrderRouteRequest(
      order,
      driverId: driverId,
      driverPosition: driverPosition,
    );
    final meters = ref
        .watch(driverOrderRouteDistanceProvider(request))
        .valueOrNull
        ?.pickupMeters;
    if (meters != null) distances[order.id] = meters;
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
