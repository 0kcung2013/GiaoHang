part of 'tracking_screen.dart';

class _TrackingHeader extends StatelessWidget {
  const _TrackingHeader();

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
              Icons.route_rounded,
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
                  'Theo dõi đơn',
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Kiểm tra trạng thái giao hàng hiện tại',
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

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const _SearchCard({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadow.card,
      ),
      child: TextField(
        controller: controller,
        onSubmitted: (_) => onSearch(),
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Nhập mã đơn hàng...',
          hintStyle: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          suffixIcon: IconButton(
            onPressed: onSearch,
            icon: const Icon(Icons.arrow_forward_rounded),
            color: AppColors.accent,
            tooltip: 'Tra cứu',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
        ),
      ),
    );
  }
}

class _TrackingTimeline extends ConsumerWidget {
  final OrderModel order;

  const _TrackingTimeline({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(orderStatusLogsProvider(order.id));
    final currentLogs = logsAsync.valueOrNull;

    return _TrackingCard(
      title: 'Tiến trình giao hàng',
      child: currentLogs != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimelineStepList(steps: _timelineSteps(order, currentLogs)),
                if (logsAsync.isRefreshing || logsAsync.isReloading) ...[
                  const SizedBox(height: AppSpacing.md),
                  const _InlineLoading(label: 'Đang cập nhật trạng thái...'),
                ],
              ],
            )
          : logsAsync.when(
              loading: () =>
                  const _InlineLoading(label: 'Đang tải trạng thái...'),
              error: (_, _) =>
                  _TimelineStepList(steps: _fallbackTimelineSteps(order)),
              data: (logs) {
                return _TimelineStepList(steps: _timelineSteps(order, logs));
              },
            ),
    );
  }
}

class _TimelineStepList extends StatelessWidget {
  final List<_TimelineStep> steps;

  const _TimelineStepList({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AppSpacing.xl2,
                child: Column(
                  children: [
                    Container(
                      width: AppSpacing.lg,
                      height: AppSpacing.lg,
                      margin: const EdgeInsets.only(top: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: step.done ? AppColors.accent : AppColors.bgCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: step.done
                              ? AppColors.accent
                              : AppColors.border,
                          width: 2,
                        ),
                        boxShadow: step.done ? AppShadow.subtle : null,
                      ),
                      child: step.done
                          ? const Icon(
                              Icons.check,
                              color: AppColors.textOnAccent,
                              size: AppSpacing.sm,
                            )
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          color: step.done
                              ? AppColors.accent.withValues(alpha: 0.45)
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl2),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: step.done
                          ? AppColors.accentLight.withValues(alpha: 0.42)
                          : AppColors.bgLight,
                      borderRadius: AppRadius.lg,
                      border: Border.all(
                        color: step.done
                            ? AppColors.accent.withValues(alpha: 0.14)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: step.done
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          step.time,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: step.done
                                ? AppColors.accent
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          step.description,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PackageInfoCard extends StatelessWidget {
  final OrderModel order;

  const _PackageInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final displayCode = order.trackingCode.isEmpty
        ? '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}'
        : order.trackingCode;
    final recipient = _joinNonEmpty([
      order.recipientName,
      order.recipientPhone,
    ]);

    return _TrackingCard(
      title: 'Thông tin gói hàng',
      icon: Icons.inventory_2_rounded,
      iconColor: AppColors.info,
      child: Column(
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Mã đơn', value: displayCode),
          _InfoRow(label: 'Trạng thái', value: _statusLabel(order.status)),
          _InfoRow(
            label: 'Người nhận',
            value: recipient.isEmpty ? 'Chưa có thông tin' : recipient,
          ),
          _InfoRow(label: 'Điểm lấy', value: order.pickupAddress),
          _InfoRow(label: 'Điểm giao', value: order.deliveryAddress),
          OrderCargoInfoBlock(
            order: order,
            compact: true,
            showEmptyState: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            label: 'Dịch vụ',
            value: _serviceTypeLabel(order.serviceType),
          ),
          _InfoRow(
            label: 'Thanh toán',
            value: _paymentMethodLabel(order.paymentMethod),
          ),
          _InfoRow(label: 'Phí giao', value: _priceText(order), isLast: true),
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Color iconColor;

  const _TrackingCard({
    required this.title,
    required this.child,
    this.icon,
    this.iconColor = AppColors.accent,
  });

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
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Chưa cập nhật' : value,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final bool showLoader;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TrackingMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.color = AppColors.accent,
    this.showLoader = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: showLoader
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 28, color: color),
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
