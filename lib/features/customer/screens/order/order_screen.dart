import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_item_model.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _OrderHeader(),
                      SizedBox(height: layout.headerGap),
                      _OrderFilterBar(
                        filters: _filters,
                        selectedIndex: _selectedFilterIndex,
                        onSelected: (i) =>
                            setState(() => _selectedFilterIndex = i),
                      ),
                    ],
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
    final asyncOrders = ref.watch(customerOrdersProvider(customerId));

    return asyncOrders.when(
      loading: () => const _OrderLoadingState(),
      error: (error, _) => _OrderErrorState(
        onRetry: () => ref.invalidate(customerOrdersProvider(customerId)),
      ),
      data: (allOrders) {
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

        return RefreshIndicator(
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
        );
      },
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

class _OrderHeader extends StatelessWidget {
  const _OrderHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.textOnDark,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn hàng',
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Theo dõi và lọc trạng thái đơn của bạn',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderFilterBar extends StatelessWidget {
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _OrderFilterBar({
    required this.filters,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpacing.xs),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final active = selectedIndex == i;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: AppDuration.normal,
              curve: AppCurve.decelerate,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: active ? AppColors.accent : Colors.transparent,
                borderRadius: AppRadius.full,
              ),
              child: Center(
                child: Text(
                  filters[i],
                  style: AppTextStyles.labelMedium.copyWith(
                    color: active
                        ? AppColors.textOnAccent
                        : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _OrderStatusView.fromStatus(order.status);
    final displayId = order.trackingCode.isNotEmpty
        ? order.trackingCode
        : '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}';

    return Material(
      color: AppColors.bgCard,
      borderRadius: AppRadius.xl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xl,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.xl,
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 132,
                decoration: BoxDecoration(
                  color: status.color,
                  borderRadius: AppRadius.full,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(status.icon, color: status.color, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayId,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _OrderInfoRow(
                      icon: Icons.person_outline_rounded,
                      text: _recipientText(order),
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _OrderInfoRow(
                      icon: Icons.storefront_rounded,
                      text: order.pickupAddress,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _OrderInfoRow(
                      icon: Icons.location_on_outlined,
                      text: order.deliveryAddress,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _OrderMetaChip(
                          icon: Icons.access_time_rounded,
                          text: _formatDateTime(order.createdAt),
                        ),
                        _OrderMetaChip(
                          icon: Icons.local_shipping_rounded,
                          text: _serviceTypeLabel(order.serviceType),
                        ),
                        _OrderMetaChip(
                          icon: Icons.payments_outlined,
                          text: _paymentMethodLabel(order.paymentMethod),
                        ),
                        _OrderMetaChip(
                          icon: Icons.attach_money_rounded,
                          text: _priceText(order),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recipientText(OrderModel order) {
    final name = order.recipientName?.trim();
    final phone = order.recipientPhone?.trim();
    if ((name == null || name.isEmpty) && (phone == null || phone.isEmpty)) {
      return 'Chưa có thông tin người nhận';
    }
    if (phone == null || phone.isEmpty) return name!;
    if (name == null || name.isEmpty) return phone;
    return '$name · $phone';
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    final hour = twoDigits(value.hour);
    final minute = twoDigits(value.minute);
    final day = twoDigits(value.day);
    final month = twoDigits(value.month);
    return '$hour:$minute · $day/$month/${value.year}';
  }

  String _serviceTypeLabel(String value) {
    return switch (value) {
      'express' => 'Hoả tốc',
      'fragile' => 'Dễ vỡ',
      'document' => 'Tài liệu',
      _ => 'Tiêu chuẩn',
    };
  }

  String _paymentMethodLabel(String value) {
    return switch (value) {
      'card' => 'Thẻ',
      'wallet' => 'Ví',
      _ => 'Tiền mặt',
    };
  }

  String _priceText(OrderModel order) {
    final amount = order.totalPrice ?? order.deliveryFee;
    if (amount <= 0) return 'Chưa tính phí';
    return '${amount.toStringAsFixed(0)}đ';
  }
}

class _OrderDetailSheet extends ConsumerStatefulWidget {
  final String customerId;
  final OrderModel order;

  const _OrderDetailSheet({required this.customerId, required this.order});

  @override
  ConsumerState<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<_OrderDetailSheet> {
  final TextEditingController _reasonController = TextEditingController();
  bool _showReasonInput = false;
  bool _isCancelling = false;

  static const Set<String> _cancellableStatuses = {'pending', 'confirmed'};

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _cancelOrder() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showSnackBar('Vui lòng nhập lý do huỷ đơn.');
      return;
    }

    setState(() => _isCancelling = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .cancelOrder(widget.order.id, widget.customerId, statusNote: reason);
      ref.invalidate(customerOrdersProvider(widget.customerId));
      ref.invalidate(orderByIdProvider(widget.order.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('Đã huỷ đơn hàng.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      _showSnackBar('Không thể huỷ đơn. Vui lòng thử lại.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = _OrderStatusView.fromStatus(order.status);
    final canCancel = _cancellableStatuses.contains(order.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.xl2 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: AppSpacing.lg),
                  _DetailHeader(order: order, status: status),
                  const SizedBox(height: AppSpacing.md),
                  _DetailSection(
                    title: 'Thông tin giao hàng',
                    children: [
                      _DetailInfoTile(
                        icon: Icons.storefront_rounded,
                        label: 'Điểm lấy',
                        value: _fallbackText(order.pickupAddress),
                      ),
                      _DetailInfoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Điểm giao',
                        value: _fallbackText(order.deliveryAddress),
                      ),
                      _DetailInfoTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Người nhận',
                        value: _fallbackText(order.recipientName),
                      ),
                      _DetailInfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Điện thoại',
                        value: _fallbackText(order.recipientPhone),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DetailSection(
                    title: 'Dịch vụ và thanh toán',
                    children: [
                      _DetailInfoTile(
                        icon: Icons.local_shipping_rounded,
                        label: 'Dịch vụ',
                        value: _serviceTypeLabel(order.serviceType),
                      ),
                      _DetailInfoTile(
                        icon: Icons.payments_outlined,
                        label: 'Thanh toán',
                        value: _paymentMethodLabel(order.paymentMethod),
                      ),
                      _DetailInfoTile(
                        icon: Icons.delivery_dining_rounded,
                        label: 'Phí giao hàng',
                        value: _money(order.deliveryFee),
                      ),
                      _DetailInfoTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Tổng tiền',
                        value: _money(order.totalPrice ?? order.deliveryFee),
                        emphasized: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _OrderItemsSection(orderId: order.id),
                  const SizedBox(height: AppSpacing.md),
                  _OrderTimelineSection(order: order),
                  if (canCancel) ...[
                    const SizedBox(height: AppSpacing.md),
                    _CancelOrderSection(
                      controller: _reasonController,
                      showReasonInput: _showReasonInput,
                      isCancelling: _isCancelling,
                      onShowReasonInput: () {
                        setState(() => _showReasonInput = true);
                      },
                      onCancel: _cancelOrder,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fallbackText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? 'Chưa cập nhật' : text;
  }

  String _serviceTypeLabel(String value) {
    return switch (value) {
      'express' => 'Hoả tốc',
      'fragile' => 'Dễ vỡ',
      'document' => 'Tài liệu',
      _ => 'Tiêu chuẩn',
    };
  }

  String _paymentMethodLabel(String value) {
    return switch (value) {
      'card' => 'Thẻ',
      'wallet' => 'Ví',
      _ => 'Tiền mặt',
    };
  }

  String _money(double amount) {
    if (amount <= 0) return 'Chưa tính phí';
    return '${amount.toStringAsFixed(0)}đ';
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadius.full,
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final OrderModel order;
  final _OrderStatusView status;

  const _DetailHeader({required this.order, required this.status});

  @override
  Widget build(BuildContext context) {
    final displayId = order.trackingCode.isNotEmpty
        ? order.trackingCode
        : '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: AppRadius.lg,
                ),
                child: Icon(status.icon, color: AppColors.textOnDark),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayId,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatOrderDateTime(order.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textOnDark.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          if ((order.statusNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              order.statusNote!.trim(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textOnDark.withValues(alpha: 0.78),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _DetailInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  const _DetailInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, size: 18, color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: emphasized
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsSection extends ConsumerWidget {
  final String orderId;

  const _OrderItemsSection({required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(orderItemsProvider(orderId));

    return _DetailSection(
      title: 'Hàng hoá',
      children: [
        itemsAsync.when(
          loading: () => const _InlineLoading(label: 'Đang tải hàng hoá...'),
          error: (_, _) => const _InlineMessage(
            icon: Icons.inventory_2_outlined,
            message: 'Không tải được hàng hoá.',
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _InlineMessage(
                icon: Icons.inventory_2_outlined,
                message: 'Chưa có hàng hoá.',
              );
            }
            return Column(
              children: [for (final item in items) _OrderItemRow(item: item)],
            );
          },
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItemModel item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name.isEmpty ? 'Hàng hoá' : item.name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'x${item.quantity}',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${item.price.toStringAsFixed(0)}đ',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTimelineSection extends ConsumerWidget {
  final OrderModel order;

  const _OrderTimelineSection({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(orderStatusLogsProvider(order.id));

    return _DetailSection(
      title: 'Trạng thái đơn hàng',
      children: [
        logsAsync.when(
          loading: () => const _InlineLoading(label: 'Đang tải trạng thái...'),
          error: (_, _) => _FallbackTimeline(order: order),
          data: (logs) {
            if (logs.isEmpty) return _FallbackTimeline(order: order);
            return Column(
              children: [
                for (var i = 0; i < logs.length; i++)
                  _TimelineRow(
                    title: logs[i].title.isEmpty
                        ? _OrderStatusView.fromStatus(logs[i].status).label
                        : logs[i].title,
                    description: logs[i].description,
                    time: _formatOrderDateTime(logs[i].createdAt),
                    status: logs[i].status,
                    isLast: i == logs.length - 1,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FallbackTimeline extends StatelessWidget {
  final OrderModel order;

  const _FallbackTimeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = _fallbackTimelineSteps(order);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            title: steps[i].title,
            description: steps[i].description,
            time: steps[i].time,
            status: steps[i].status,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String title;
  final String? description;
  final String time;
  final String status;
  final bool isLast;

  const _TimelineRow({
    required this.title,
    required this.description,
    required this.time,
    required this.status,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final statusView = _OrderStatusView.fromStatus(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: statusView.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(statusView.icon, size: 16, color: statusView.color),
            ),
            if (!isLast)
              Container(width: 2, height: 46, color: AppColors.border),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  time,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0,
                  ),
                ),
                if ((description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description!.trim(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelOrderSection extends StatelessWidget {
  final TextEditingController controller;
  final bool showReasonInput;
  final bool isCancelling;
  final VoidCallback onShowReasonInput;
  final VoidCallback onCancel;

  const _CancelOrderSection({
    required this.controller,
    required this.showReasonInput,
    required this.isCancelling,
    required this.onShowReasonInput,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: 'Huỷ đơn hàng',
      children: [
        Text(
          'Chỉ áp dụng cho đơn đang chờ xác nhận hoặc đã xác nhận.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (showReasonInput) ...[
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 4,
            enabled: !isCancelling,
            decoration: InputDecoration(
              hintText: 'Nhập lý do huỷ đơn',
              filled: true,
              fillColor: AppColors.bgLight,
              border: OutlineInputBorder(
                borderRadius: AppRadius.lg,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.lg,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.lg,
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _DangerActionButton(
            label: isCancelling ? 'Đang huỷ...' : 'Xác nhận huỷ đơn',
            onTap: isCancelling ? null : onCancel,
          ),
        ] else
          _DangerActionButton(label: 'Huỷ đơn hàng', onTap: onShowReasonInput),
      ],
    );
  }
}

class _DangerActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _DangerActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null
          ? AppColors.textMuted.withValues(alpha: 0.24)
          : AppColors.error,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  final String label;

  const _InlineLoading({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep {
  final String title;
  final String? description;
  final String time;
  final String status;

  const _TimelineStep({
    required this.title,
    required this.description,
    required this.time,
    required this.status,
  });
}

List<_TimelineStep> _fallbackTimelineSteps(OrderModel order) {
  final statusView = _OrderStatusView.fromStatus(order.status);
  final createdTime = _formatOrderDateTime(order.createdAt);
  final updatedTime = order.updatedAt.millisecondsSinceEpoch > 0
      ? _formatOrderDateTime(order.updatedAt)
      : createdTime;

  if (order.status == 'pending') {
    return [
      _TimelineStep(
        title: statusView.label,
        description: 'Đơn hàng đã được tạo và đang chờ xác nhận.',
        time: createdTime,
        status: order.status,
      ),
    ];
  }

  return [
    _TimelineStep(
      title: 'Đã tạo đơn',
      description: 'Đơn hàng đã được ghi nhận trong hệ thống.',
      time: createdTime,
      status: 'pending',
    ),
    _TimelineStep(
      title: statusView.label,
      description: order.status == 'cancelled'
          ? (order.statusNote?.trim().isNotEmpty ?? false
                ? order.statusNote!.trim()
                : 'Đơn hàng đã bị huỷ.')
          : 'Cập nhật gần nhất của đơn hàng.',
      time: updatedTime,
      status: order.status,
    ),
  ];
}

String _formatOrderDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final hour = twoDigits(value.hour);
  final minute = twoDigits(value.minute);
  final day = twoDigits(value.day);
  final month = twoDigits(value.month);
  return '$hour:$minute · $day/$month/${value.year}';
}

class _OrderStatusView {
  final String label;
  final Color color;
  final IconData icon;

  const _OrderStatusView({
    required this.label,
    required this.color,
    required this.icon,
  });

  factory _OrderStatusView.fromStatus(String status) {
    return switch (status) {
      'pending' => const _OrderStatusView(
        label: 'Chờ xác nhận',
        color: AppColors.warning,
        icon: Icons.access_time_rounded,
      ),
      'confirmed' => const _OrderStatusView(
        label: 'Đã xác nhận',
        color: AppColors.info,
        icon: Icons.check_circle_rounded,
      ),
      'assigned' => const _OrderStatusView(
        label: 'Đã phân công',
        color: AppColors.info,
        icon: Icons.local_shipping_rounded,
      ),
      'picking_up' => const _OrderStatusView(
        label: 'Đang lấy hàng',
        color: AppColors.accent,
        icon: Icons.inventory_2_rounded,
      ),
      'delivering' => const _OrderStatusView(
        label: 'Đang giao',
        color: AppColors.accent,
        icon: Icons.local_shipping_rounded,
      ),
      'delivered' => const _OrderStatusView(
        label: 'Hoàn thành',
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      ),
      'cancelled' => const _OrderStatusView(
        label: 'Huỷ',
        color: AppColors.error,
        icon: Icons.cancel_rounded,
      ),
      _ => const _OrderStatusView(
        label: 'Không rõ',
        color: AppColors.textMuted,
        icon: Icons.help_outline_rounded,
      ),
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final _OrderStatusView status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: status.color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final FontWeight fontWeight;
  final int maxLines;

  const _OrderInfoRow({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
    this.fontWeight = FontWeight.w500,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: fontWeight,
              height: 1.35,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OrderMetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OrderMetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderLoadingState extends StatelessWidget {
  const _OrderLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.xl2,
      ),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => const _LoadingCard(),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LoadingBar(width: 140),
          const SizedBox(height: AppSpacing.md),
          _LoadingBar(width: double.infinity),
          const SizedBox(height: AppSpacing.sm),
          _LoadingBar(width: 220),
          const Spacer(),
          _LoadingBar(width: 180),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  final double width;

  const _LoadingBar({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.7),
        borderRadius: AppRadius.full,
      ),
    );
  }
}

class _OrderErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _OrderErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _OrderMessageState(
      icon: Icons.error_outline_rounded,
      title: 'Không tải được đơn hàng',
      message: 'Vui lòng kiểm tra kết nối và thử lại.',
      actionLabel: 'Thử lại',
      onAction: onRetry,
      color: AppColors.error,
    );
  }
}

class _OrderMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  const _OrderMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.screenH),
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.lg,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _StateActionButton(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class _StateActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StateActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textOnAccent,
            ),
          ),
        ),
      ),
    );
  }
}
