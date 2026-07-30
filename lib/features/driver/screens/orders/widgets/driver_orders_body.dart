import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../home/utils/driver_home_formatters.dart';
import '../../home/widgets/driver_state_widgets.dart';
import '../utils/driver_order_filter.dart';
import 'driver_orders_filter_bar.dart';
import 'driver_orders_list.dart';

class DriverOrdersBody extends ConsumerStatefulWidget {
  final String userId;

  const DriverOrdersBody({super.key, required this.userId});

  @override
  ConsumerState<DriverOrdersBody> createState() => _DriverOrdersBodyState();
}

class _DriverOrdersBodyState extends ConsumerState<DriverOrdersBody> {
  DriverOrderFilter _selectedFilter = DriverOrderFilter.available;

  @override
  Widget build(BuildContext context) {
    _debugLog('authUser=${widget.userId} selectedFilter=$_selectedFilter');
    final driverAsync = ref.watch(driverByUserIdProvider(widget.userId));
    final availableOrdersAsync = ref.watch(
      availableOrdersProvider(widget.userId),
    );

    return driverAsync.when(
      loading: () => const DriverLoadingState(),
      error: (_, _) => DriverErrorState(
        onRetry: () {
          ref.invalidate(driverByUserIdProvider(widget.userId));
          ref.invalidate(availableOrdersProvider(widget.userId));
        },
      ),
      data: (driver) {
        if (driver == null) return const MissingDriverProfileState();
        _debugLog('driverProfile id=${driver.id} userId=${driver.userId}');

        final driverOrdersAsync = ref.watch(
          driverOrdersProvider(driver.userId),
        );
        final isLoading =
            availableOrdersAsync.isLoading || driverOrdersAsync.isLoading;
        final hasError =
            availableOrdersAsync.hasError || driverOrdersAsync.hasError;

        if (isLoading) return const DriverLoadingState();

        if (hasError) {
          _debugLog(
            'providerError available=${availableOrdersAsync.error} '
            'driverOrders=${driverOrdersAsync.error}',
          );
          return DriverErrorState(
            onRetry: () {
              ref.invalidate(availableOrdersProvider(widget.userId));
              ref.invalidate(driverOrdersProvider(driver.userId));
            },
          );
        }

        final rawAvailableOrders =
            availableOrdersAsync.valueOrNull ?? const <OrderModel>[];
        final driverOrders =
            driverOrdersAsync.valueOrNull ?? const <OrderModel>[];
        final hasActiveOrder = driverOrders.any(isActiveDriverOrder);
        final availableOrders = driver.isAvailable && !hasActiveOrder
            ? rawAvailableOrders
            : const <OrderModel>[];

        final showAvailableTab = driver.isAvailable && !hasActiveOrder;
        final visibleFilters = showAvailableTab
            ? DriverOrderFilter.values
            : DriverOrderFilter.values
                  .where((f) => f != DriverOrderFilter.available)
                  .toList();

        if (!visibleFilters.contains(_selectedFilter)) {
          _selectedFilter = visibleFilters.first;
        }

        final counts = {
          for (final filter in visibleFilters)
            filter: filter
                .filter(
                  availableOrders: availableOrders,
                  driverOrders: driverOrders,
                )
                .length,
        };
        final visibleOrders = _selectedFilter.filter(
          availableOrders: availableOrders,
          driverOrders: driverOrders,
        );
        _debugLog(
          'counts available=${availableOrders.length} '
          'driver=${driverOrders.length} visible=${visibleOrders.length} '
          'visibleOrders=${visibleOrders.map((order) => '${order.id}:${order.status}:${order.driverId ?? 'null'}').join(',')}',
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DriverOrdersFilterBar(
              filters: visibleFilters,
              selectedFilter: _selectedFilter,
              counts: counts,
              onChanged: (filter) => setState(() => _selectedFilter = filter),
            ),
            const SizedBox(height: AppSpacing.xl2),
            DriverOrdersList(
              filter: _selectedFilter,
              orders: visibleOrders,
              acceptDriverId: _selectedFilter == DriverOrderFilter.available
                  ? driver.userId
                  : null,
            ),
          ],
        );
      },
    );
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[DriverOrders] $message');
    }
  }
}
