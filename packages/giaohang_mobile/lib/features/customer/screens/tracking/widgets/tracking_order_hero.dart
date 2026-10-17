part of '../tracking_screen.dart';

class _TrackedOrderHero extends StatelessWidget {
  const _TrackedOrderHero({
    required this.order,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final OrderModel order;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final showMap = _shouldShowOrderMap(order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TrackingOrderMeta(order: order),
        const SizedBox(height: AppSpacing.md),
        if (showMap)
          LayoutBuilder(
            builder: (context, constraints) {
              final mapHeight = constraints.maxWidth >= 600 ? 400.0 : 340.0;
              return SizedBox(
                child: Column(
                  children: [
                    _TrackingMap(order: order, height: mapHeight),
                    const SizedBox(height: AppSpacing.md),
                    _TrackingStatusSurface(
                      order: order,
                      isRefreshing: isRefreshing,
                      onRefresh: onRefresh,
                    ),
                  ],
                ),
              );
            },
          )
        else
          _TrackingStatusSurface(
            order: order,
            isRefreshing: isRefreshing,
            onRefresh: onRefresh,
          ),
      ],
    );
  }
}

class _TrackingOrderMeta extends StatelessWidget {
  const _TrackingOrderMeta({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final code = order.trackingCode.isEmpty
        ? order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)
        : order.trackingCode;
    final status = order.effectiveStatusAt(DateTime.now());
    final badgeColor = _trackingStatusColor(status);
    final badgeLabel = switch (status) {
      'delivered' || 'returned' => 'Đã hoàn tất',
      'cancelled' => 'Đã kết thúc',
      _ => 'Cập nhật trực tiếp',
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            'Đơn #$code',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.mono.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: AppRadius.full,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                badgeLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackingStatusSurface extends StatelessWidget {
  const _TrackingStatusSurface({
    required this.order,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final OrderModel order;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = order.effectiveStatusAt(DateTime.now());
    final statusColor = _trackingStatusColor(status);
    return Semantics(
      container: true,
      label: _statusLabel(status),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl2,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.11),
                    borderRadius: AppRadius.lg,
                  ),
                  child: Icon(
                    _trackingStatusIcon(status),
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRẠNG THÁI HIỆN TẠI',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _statusLabel(status),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headingMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _TrackingRefreshButton(
                  isRefreshing: isRefreshing,
                  onTap: onRefresh,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: AppRadius.full,
              child: LinearProgressIndicator(
                value: _trackingProgress(status),
                minHeight: 6,
                backgroundColor: AppColors.accentLight,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (status == 'cancelled')
              Text(OrderEtaStrings.ended, style: AppTextStyles.bodySmall)
            else if (status == 'delivered' && order.actualDeliveredAt != null)
              Text(
                'Đã giao lúc ${_formatTrackingClock(order.actualDeliveredAt!)}',
                style: AppTextStyles.bodySmall,
              )
            else
              OrderEtaPanel(order: order),
          ],
        ),
      ),
    );
  }
}

class _TrackingRefreshButton extends StatelessWidget {
  const _TrackingRefreshButton({
    required this.isRefreshing,
    required this.onTap,
  });

  final bool isRefreshing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Làm mới trạng thái đơn hàng',
      child: Material(
        color: AppColors.accentLight,
        borderRadius: AppRadius.full,
        child: InkWell(
          onTap: isRefreshing ? null : onTap,
          borderRadius: AppRadius.full,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.accent,
                      size: 23,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTrackingClock(DateTime value) {
  final local = VietnamTime.toWallClock(value);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)} · '
      '${two(local.day)}/${two(local.month)}';
}

Color _trackingStatusColor(String status) {
  if (status == 'delivered' || status == 'returned') return AppColors.success;
  if (status == 'cancelled') return AppColors.error;
  if (status == 'pending' ||
      status == 'confirmed' ||
      status == 'assignment_timeout') {
    return AppColors.warning;
  }
  return AppColors.accent;
}

IconData _trackingStatusIcon(String status) {
  return switch (status) {
    'delivered' => Icons.check_circle_rounded,
    'returned' => Icons.assignment_return_rounded,
    'cancelled' => Icons.cancel_rounded,
    'assignment_timeout' => Icons.person_search_rounded,
    'picking_up' => Icons.inventory_2_rounded,
    'delivering' => Icons.local_shipping_rounded,
    _ => Icons.schedule_rounded,
  };
}

double _trackingProgress(String status) {
  return switch (status) {
    'pending' => 0.12,
    'confirmed' => 0.25,
    'assignment_timeout' => 0.25,
    'assigned' => 0.42,
    'picking_up' => 0.58,
    'delivering' => 0.78,
    'return_approved' => 0.66,
    'returning' => 0.82,
    'returned' || 'delivered' => 1,
    'cancelled' => 1,
    _ => 0.08,
  };
}
