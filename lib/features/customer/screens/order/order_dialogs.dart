part of 'order_screen.dart';

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
                    title: 'Hàng hoá',
                    children: [
                      OrderCargoInfoBlock(order: order, showEmptyState: true),
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
