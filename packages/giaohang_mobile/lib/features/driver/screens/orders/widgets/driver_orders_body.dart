import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../home/utils/driver_home_formatters.dart';
import '../../home/widgets/driver_state_widgets.dart';
import '../utils/driver_order_filter.dart';
import 'driver_orders_filter_bar.dart';
import 'driver_orders_list.dart';
import 'driver_orders_overview.dart';

class DriverOrdersBody extends ConsumerStatefulWidget {
  final String userId;
  final EdgeInsets contentPadding;
  final double maxContentWidth;

  const DriverOrdersBody({
    super.key,
    required this.userId,
    required this.contentPadding,
    required this.maxContentWidth,
  });

  @override
  ConsumerState<DriverOrdersBody> createState() => _DriverOrdersBodyState();
}

class _DriverOrdersBodyState extends ConsumerState<DriverOrdersBody> {
  DriverOrderFilter _selectedFilter = DriverOrderFilter.available;

  @override
  Widget build(BuildContext context) {
    _debugLog(
      () => 'authUser=${widget.userId} selectedFilter=$_selectedFilter',
    );
    final driverAsync = ref.watch(driverByUserIdProvider(widget.userId));
    final availableOrdersAsync = ref.watch(
      availableOrdersProvider(widget.userId),
    );

    return driverAsync.when(
      loading: () => _scrollState(const DriverLoadingState()),
      error: (_, _) => _scrollState(
        DriverErrorState(
          onRetry: () {
            ref.invalidate(driverByUserIdProvider(widget.userId));
            ref.invalidate(availableOrdersProvider(widget.userId));
          },
        ),
      ),
      data: (driver) {
        if (driver == null) {
          return _scrollState(const MissingDriverProfileState());
        }
        _debugLog(
          () => 'driverProfile id=${driver.id} userId=${driver.userId}',
        );

        final driverOrdersAsync = ref.watch(
          driverOrdersProvider(driver.userId),
        );
        final isLoading =
            availableOrdersAsync.isLoading || driverOrdersAsync.isLoading;
        final hasError =
            availableOrdersAsync.hasError || driverOrdersAsync.hasError;

        if (isLoading) return _scrollState(const DriverLoadingState());

        if (hasError) {
          _debugLog(
            () =>
                'providerError available=${availableOrdersAsync.error} '
                'driverOrders=${driverOrdersAsync.error}',
          );
          return _scrollState(
            DriverErrorState(
              onRetry: () {
                ref.invalidate(availableOrdersProvider(widget.userId));
                ref.invalidate(driverOrdersProvider(driver.userId));
              },
            ),
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

        final allCounts = {
          for (final filter in DriverOrderFilter.values)
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
          () =>
              'counts available=${availableOrders.length} '
              'driver=${driverOrders.length} visible=${visibleOrders.length}',
        );

        return DriverOrdersList(
          filter: _selectedFilter,
          orders: visibleOrders,
          acceptDriverId: _selectedFilter == DriverOrderFilter.available
              ? driver.userId
              : null,
          contentPadding: widget.contentPadding,
          maxContentWidth: widget.maxContentWidth,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DriverOrdersOverview(
                isAvailable: driver.isAvailable,
                hasActiveOrder: hasActiveOrder,
                availableCount: allCounts[DriverOrderFilter.available] ?? 0,
                activeCount: allCounts[DriverOrderFilter.active] ?? 0,
                completedCount: allCounts[DriverOrderFilter.completed] ?? 0,
              ),
              const SizedBox(height: AppSpacing.lg),
              DriverOrdersFilterBar(
                filters: visibleFilters,
                selectedFilter: _selectedFilter,
                counts: allCounts,
                onChanged: (filter) => setState(() => _selectedFilter = filter),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _scrollState(Widget child) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: widget.contentPadding,
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _debugLog(String Function() message) {
    if (kDebugMode) {
      debugPrint('[DriverOrders] ${message()}');
    }
  }
}
