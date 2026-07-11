import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_item_model.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/widgets/order_cargo_info_block.dart';

part 'order_widgets.dart';
part 'order_dialogs.dart';
part 'order_helpers.dart';

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  int _selectedFilterIndex = 0;

  static const List<String> _filters = [
    'Tất cả',
    'Đang giao',
    'Hoàn thành',
    'Huỷ',
  ];

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    final activeFilter = _filters[_selectedFilterIndex];

    return orders.where((order) {
      return switch (activeFilter) {
        'Đang giao' => _activeStatuses.contains(order.status),
        'Hoàn thành' => order.status == 'delivered',
        'Huỷ' => order.status == 'cancelled',
        _ => true,
      };
    }).toList();
  }

  static const Set<String> _activeStatuses = {
    'pending',
    'confirmed',
    'assigned',
    'picking_up',
    'delivering',
  };

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _OrderLayout.fromWidth(constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                layout.horizontalPadding,
                layout.topPadding,
                layout.horizontalPadding,
                AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                  child: _OrderFilterBar(
                    filters: _filters,
                    selectedIndex: _selectedFilterIndex,
                    onSelected: (i) =>
                        setState(() => _selectedFilterIndex = i),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                  child: currentUser == null
                      ? const _OrderMessageState(
                          icon: Icons.lock_outline_rounded,
                          title: 'Cần đăng nhập để xem đơn hàng',
                          message:
                              'Vui lòng đăng nhập để tải danh sách đơn hàng của bạn.',
                        )
                      : _OrderListBody(
                          customerId: currentUser.id,
                          layout: layout,
                          orders: _filterOrders,
                          selectedFilter: _filters[_selectedFilterIndex],
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
  final List<OrderModel> Function(List<OrderModel> orders) orders;
  final String selectedFilter;

  const _OrderListBody({
    required this.customerId,
    required this.layout,
    required this.orders,
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersRealtimeProvider(customerId));
    final asyncOrders = ref.watch(customerOrdersProvider(customerId));
    final currentOrders = asyncOrders.valueOrNull;

    if (currentOrders != null) {
      return _buildOrdersContent(
        context: context,
        ref: ref,
        allOrders: currentOrders,
        isRefreshing: asyncOrders.isRefreshing || asyncOrders.isReloading,
      );
    }

    return asyncOrders.when(
      loading: () => const _OrderLoadingState(),
      error: (error, _) => _OrderErrorState(
        onRetry: () => ref.invalidate(customerOrdersProvider(customerId)),
      ),
      data: (allOrders) => _buildOrdersContent(
        context: context,
        ref: ref,
        allOrders: allOrders,
        isRefreshing: false,
      ),
    );
  }

  Widget _buildOrdersContent({
    required BuildContext context,
    required WidgetRef ref,
    required List<OrderModel> allOrders,
    required bool isRefreshing,
  }) {
    final visibleOrders = orders(allOrders);
    if (allOrders.isEmpty) {
      return const _OrderMessageState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có đơn hàng nào',
        message: 'Các đơn hàng bạn tạo sẽ xuất hiện tại đây.',
      );
    }

    if (visibleOrders.isEmpty) {
      return _OrderMessageState(
        icon: Icons.filter_alt_off_rounded,
        title: 'Không tìm thấy đơn hàng',
        message: 'Không có đơn hàng nào trong mục "$selectedFilter".',
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
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              layout.horizontalPadding,
              0,
              layout.horizontalPadding,
              AppSpacing.xl2,
            ),
            itemCount: visibleOrders.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              return _OrderCard(
                order: visibleOrders[i],
                onTap: () => _showOrderDetailSheet(
                  context: context,
                  customerId: customerId,
                  order: visibleOrders[i],
                ),
              );
            },
          ),
        ),
        if (isRefreshing)
          Positioned(
            top: 0,
            left: layout.horizontalPadding,
            right: layout.horizontalPadding,
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

void _showOrderDetailSheet({
  required BuildContext context,
  required String customerId,
  required OrderModel order,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _OrderDetailSheet(customerId: customerId, order: order);
    },
  );
}

class _OrderLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const tabletContentMaxWidth = 760.0;
  static const desktopContentMaxWidth = 820.0;

  final double horizontalPadding;
  final double topPadding;
  final double headerGap;
  final double maxContentWidth;

  const _OrderLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.headerGap,
    required this.maxContentWidth,
  });

  factory _OrderLayout.fromWidth(double width) {
    if (width > desktopBreakpoint) {
      return const _OrderLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        headerGap: AppSpacing.xl,
        maxContentWidth: desktopContentMaxWidth,
      );
    }

    if (width >= tabletBreakpoint) {
      return const _OrderLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        headerGap: AppSpacing.xl,
        maxContentWidth: tabletContentMaxWidth,
      );
    }

    return const _OrderLayout(
      horizontalPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      headerGap: AppSpacing.lg,
      maxContentWidth: double.infinity,
    );
  }
}
