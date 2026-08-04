import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import 'order_widgets.dart' as widgets;
import 'order_dialogs.dart' as dialogs;

export 'order_helpers.dart'
    show fallbackTimelineSteps, OrderStatusView, formatOrderDateTime;
export 'order_widgets.dart'
    show
        OrderFilterBar,
        OrderCard,
        OrderShimmer,
        OrderEmptyState,
        OrderErrorState,
        OrderLoginRequired;
export 'order_dialogs.dart' show showOrderDetailSheet;

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  int _selectedFilterIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<_FilterOption> _filters = [
    _FilterOption('Tất cả', Icons.view_stream_rounded, null),
    _FilterOption('Đang xử lý', Icons.local_shipping_rounded, _activeStatuses),
    _FilterOption('Hoàn thành', Icons.task_alt_rounded, {'delivered'}),
    _FilterOption('Đã huỷ', Icons.cancel_rounded, {'cancelled'}),
  ];

  static const Set<String> _activeStatuses = {
    'pending',
    'confirmed',
    'assigned',
    'picking_up',
    'delivering',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OrderModel> _applyFilters(
    List<OrderModel> orders,
    Set<String>? statuses,
    String query,
  ) {
    var filtered = orders;
    if (statuses != null) {
      final now = DateTime.now();
      filtered = filtered
          .where((o) => statuses.contains(o.effectiveStatusAt(now)))
          .toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((o) {
        final code = o.trackingCode.isNotEmpty
            ? o.trackingCode
            : '#${o.id.substring(0, o.id.length >= 8 ? 8 : o.id.length)}';
        return code.toLowerCase().contains(q) ||
            o.deliveryAddress.toLowerCase().contains(q) ||
            o.pickupAddress.toLowerCase().contains(q) ||
            (o.recipientName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _OrderLayout.fromWidth(constraints.maxWidth);

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                layout.hPadding,
                layout.topPadding,
                layout.hPadding,
                AppSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: layout.maxWidth),
                  child: widgets.OrderCompactToolbar(
                    onCreateOrder: () => context.push('/customer/create-order'),
                    controller: _searchController,
                    onSearchChanged: (v) =>
                        setState(() => _searchQuery = v.trim()),
                    filters: _filters.map((f) => f.label).toList(),
                    filterIcons: _filters.map((f) => f.icon).toList(),
                    selectedIndex: _selectedFilterIndex,
                    onFilterSelected: (i) =>
                        setState(() => _selectedFilterIndex = i),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: layout.maxWidth),
                  child: currentUser == null
                      ? const widgets.OrderLoginRequired()
                      : _OrderListBody(
                          customerId: currentUser.id,
                          layout: layout,
                          selectedFilter: _filters[_selectedFilterIndex],
                          searchQuery: _searchQuery,
                          applyFilters: _applyFilters,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrderListBody extends ConsumerWidget {
  final String customerId;
  final _OrderLayout layout;
  final _FilterOption selectedFilter;
  final String searchQuery;
  final List<OrderModel> Function(List<OrderModel>, Set<String>?, String)
  applyFilters;

  const _OrderListBody({
    required this.customerId,
    required this.layout,
    required this.selectedFilter,
    required this.searchQuery,
    required this.applyFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersRealtimeProvider(customerId));
    final asyncOrders = ref.watch(customerOrdersProvider(customerId));
    final currentOrders = asyncOrders.valueOrNull;

    if (currentOrders != null) {
      return _buildContent(
        context: context,
        ref: ref,
        allOrders: currentOrders,
        isRefreshing: asyncOrders.isRefreshing || asyncOrders.isReloading,
      );
    }

    return asyncOrders.when(
      loading: () => const widgets.OrderShimmer(),
      error: (error, _) => widgets.OrderErrorState(
        onRetry: () => ref.invalidate(customerOrdersProvider(customerId)),
      ),
      data: (allOrders) => _buildContent(
        context: context,
        ref: ref,
        allOrders: allOrders,
        isRefreshing: false,
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required WidgetRef ref,
    required List<OrderModel> allOrders,
    required bool isRefreshing,
  }) {
    final visibleOrders = applyFilters(
      allOrders,
      selectedFilter.statuses,
      searchQuery,
    );

    if (allOrders.isEmpty) {
      return const widgets.OrderEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có đơn hàng nào',
        message: 'Các đơn hàng bạn tạo sẽ xuất hiện tại đây.',
      );
    }

    if (visibleOrders.isEmpty) {
      return widgets.OrderEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Không tìm thấy đơn hàng',
        message: searchQuery.isNotEmpty
            ? 'Không có đơn nào khớp với "$searchQuery".'
            : 'Không có đơn hàng nào trong mục "${selectedFilter.label}".',
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(customerOrdersProvider(customerId));
            await ref.read(customerOrdersProvider(customerId).future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              layout.hPadding,
              0,
              layout.hPadding,
              AppSpacing.xl2,
            ),
            itemCount: visibleOrders.length + 1,
            itemBuilder: (context, i) {
              if (i == visibleOrders.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Semantics(
                    label: '${visibleOrders.length} đơn hàng',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${visibleOrders.length}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final order = visibleOrders[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: widgets.OrderCard(
                  order: order,
                  isFeatured:
                      i == 0 &&
                      _OrderScreenState._activeStatuses.contains(
                        order.effectiveStatusAt(DateTime.now()),
                      ),
                  onTap: () {
                    if (order.isAssignmentTimedOutAt(DateTime.now()) &&
                        order.trackingCode.trim().isNotEmpty) {
                      context.go(
                        '/customer-home?tab=tracking&code='
                        '${Uri.encodeComponent(order.trackingCode)}',
                      );
                      return;
                    }
                    dialogs.showOrderDetailSheet(
                      context: context,
                      customerId: customerId,
                      order: order,
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (isRefreshing)
          Positioned(
            top: 0,
            left: layout.hPadding,
            right: layout.hPadding,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.accent.withValues(alpha: 0.72),
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

class _OrderLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;

  final double hPadding;
  final double topPadding;
  final double maxWidth;

  const _OrderLayout({
    required this.hPadding,
    required this.topPadding,
    required this.maxWidth,
  });

  factory _OrderLayout.fromWidth(double width) {
    if (width >= desktopBreakpoint) {
      return const _OrderLayout(
        hPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        maxWidth: 820,
      );
    }
    if (width >= tabletBreakpoint) {
      return const _OrderLayout(
        hPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        maxWidth: 760,
      );
    }
    return const _OrderLayout(
      hPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      maxWidth: double.infinity,
    );
  }
}

class _FilterOption {
  final String label;
  final IconData icon;
  final Set<String>? statuses;

  const _FilterOption(this.label, this.icon, this.statuses);
}
