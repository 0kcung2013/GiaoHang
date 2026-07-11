part of 'order_screen.dart';

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
