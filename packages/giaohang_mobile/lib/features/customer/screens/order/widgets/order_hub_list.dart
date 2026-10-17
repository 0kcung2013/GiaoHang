import '../utils/order_hub_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../order_dialogs.dart';
import '../utils/order_history_filter.dart';
import 'order_card.dart';
import 'order_history_card.dart';
import 'order_hub_controls.dart';
import 'order_list_states.dart';

class OrderHubList extends ConsumerWidget {
  const OrderHubList({
    super.key,
    required this.customerId,
    required this.history,
    required this.query,
    required this.filter,
    required this.onFilter,
  });
  final String customerId;
  final bool history;
  final String query;
  final OrderHistoryFilter filter;
  final ValueChanged<OrderHistoryFilter> onFilter;

  void _open(BuildContext context, OrderModel order) {
    if (order.isAssignmentTimedOutAt(DateTime.now()) &&
        order.trackingCode.trim().isNotEmpty) {
      context.go(
        '/customer-home?tab=tracking&code=${Uri.encodeComponent(order.trackingCode)}',
      );
      return;
    }
    showOrderDetailSheet(
      context: context,
      customerId: customerId,
      order: order,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersRealtimeProvider(customerId));
    final orders = ref.watch(customerOrdersProvider(customerId));
    final current = orders.valueOrNull;
    if (current == null) {
      return orders.when(
        loading: () => const OrderShimmer(),
        error: (_, _) => OrderErrorState(
          onRetry: () => ref.invalidate(customerOrdersProvider(customerId)),
        ),
        data: (value) => _content(context, ref, value, false),
      );
    }
    return _content(
      context,
      ref,
      current,
      orders.isRefreshing || orders.isReloading,
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    List<OrderModel> all,
    bool refreshing,
  ) {
    final now = DateTime.now();
    final visible = filterCustomerOrders(
      all,
      history: history,
      query: query,
      filter: filter,
      now: now,
    );
    final hasFilters =
        query.isNotEmpty ||
        (history &&
            (filter.period != OrderPeriod.all ||
                filter.status != OrderHistoryStatus.all));
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(customerOrdersProvider(customerId));
            await ref.read(customerOrdersProvider(customerId).future);
          },
          child: CustomScrollView(
            key: PageStorageKey(
              history ? 'customer-order-history' : 'customer-order-active',
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (history)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: OrderHistoryControls(
                      filter: filter,
                      onChanged: onFilter,
                    ),
                  ),
                ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: OrderEmptyState(
                    icon: hasFilters
                        ? Icons.search_off_rounded
                        : Icons.receipt_long_outlined,
                    title: hasFilters
                        ? OrderHubStrings.noResults
                        : history
                        ? OrderHubStrings.emptyHistory
                        : OrderHubStrings.emptyActive,
                    message: hasFilters
                        ? OrderHubStrings.changeFilters
                        : history
                        ? OrderHubStrings.historyHint
                        : OrderHubStrings.activeHint,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.sm,
                    AppSpacing.screenH,
                    AppSpacing.xl2,
                  ),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final order = visible[index];
                      final group = filter.groupLabel(order.createdAt);
                      final showGroup =
                          history &&
                          (index == 0 ||
                              group !=
                                  filter.groupLabel(
                                    visible[index - 1].createdAt,
                                  ));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showGroup)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                                bottom: AppSpacing.md,
                              ),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  group,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: history
                                ? OrderHistoryCard(
                                    order: order,
                                    onTap: () => _open(context, order),
                                  )
                                : OrderCard(
                                    order: order,
                                    isFeatured: index == 0,
                                    onTap: () => _open(context, order),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (refreshing)
          const Positioned(
            top: 0,
            left: AppSpacing.screenH,
            right: AppSpacing.screenH,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.accent,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}
