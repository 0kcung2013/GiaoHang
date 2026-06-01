import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/order_status_log_model.dart';
import '../../../../core/providers/customer_providers.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _searchController = TextEditingController();
  String? _trackingCode;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final value = _searchController.text.trim();
    if (value.isEmpty) {
      setState(() => _trackingCode = null);
      return;
    }
    setState(() => _trackingCode = value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _TrackingLayout.fromWidth(constraints.maxWidth);
        final trackingCode = _trackingCode;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            layout.topPadding,
            layout.horizontalPadding,
            AppSpacing.xl2,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TrackingHeader(),
                  SizedBox(height: layout.headerGap),
                  _SearchCard(
                    controller: _searchController,
                    onSearch: _submitSearch,
                  ),
                  SizedBox(height: layout.sectionGap),
                  if (trackingCode == null)
                    const _TrackingMessageCard(
                      icon: Icons.search_rounded,
                      title: 'Nhập mã đơn hàng',
                      message:
                          'Tra cứu bằng mã vận đơn để xem trạng thái giao hàng hiện tại.',
                    )
                  else
                    _TrackingLookupResult(trackingCode: trackingCode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackingLookupResult extends ConsumerWidget {
  final String trackingCode;

  const _TrackingLookupResult({required this.trackingCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrder = ref.watch(orderByTrackingCodeProvider(trackingCode));

    return asyncOrder.when(
      loading: () => const _TrackingMessageCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Đang tải đơn hàng',
        message: 'Vui lòng chờ trong giây lát.',
        showLoader: true,
      ),
      error: (_, _) => _TrackingMessageCard(
        icon: Icons.error_outline_rounded,
        title: 'Không tải được đơn hàng',
        message: 'Vui lòng kiểm tra kết nối và thử lại.',
        color: AppColors.error,
        actionLabel: 'Thử lại',
        onAction: () =>
            ref.invalidate(orderByTrackingCodeProvider(trackingCode)),
      ),
      data: (order) {
        if (order == null) {
          return const _TrackingMessageCard(
            icon: Icons.inventory_2_outlined,
            title: 'Không tìm thấy đơn hàng',
            message: 'Mã đơn hàng không tồn tại hoặc bạn không có quyền xem.',
          );
        }

        return Column(
          children: [
            _TrackingTimeline(order: order),
            const SizedBox(height: AppSpacing.xl2 + AppSpacing.xs),
            _PackageInfoCard(order: order),
          ],
        );
      },
    );
  }
}

class _TrackingLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const tabletContentMaxWidth = 720.0;
  static const desktopContentMaxWidth = 760.0;

  final double horizontalPadding;
  final double topPadding;
  final double headerGap;
  final double sectionGap;
  final double maxContentWidth;

  const _TrackingLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.headerGap,
    required this.sectionGap,
    required this.maxContentWidth,
  });

  factory _TrackingLayout.fromWidth(double width) {
    if (width > desktopBreakpoint) {
      return const _TrackingLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        headerGap: AppSpacing.xl,
        sectionGap: AppSpacing.xl3,
        maxContentWidth: desktopContentMaxWidth,
      );
    }

    if (width >= tabletBreakpoint) {
      return const _TrackingLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        headerGap: AppSpacing.xl,
        sectionGap: AppSpacing.xl2,
        maxContentWidth: tabletContentMaxWidth,
      );
    }

    return const _TrackingLayout(
      horizontalPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      headerGap: AppSpacing.lg,
      sectionGap: AppSpacing.xl2 + AppSpacing.xs,
      maxContentWidth: double.infinity,
    );
  }
}

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

class _TimelineStep {
  final String title;
  final String time;
  final String description;
  final bool done;

  const _TimelineStep({
    required this.title,
    required this.time,
    required this.description,
    required this.done,
  });
}

class _TrackingTimeline extends ConsumerWidget {
  final OrderModel order;

  const _TrackingTimeline({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(orderStatusLogsProvider(order.id));

    return _TrackingCard(
      title: 'Tiến trình giao hàng',
      child: logsAsync.when(
        loading: () => const _InlineLoading(label: 'Đang tải trạng thái...'),
        error: (_, _) =>
            _TimelineStepList(steps: _fallbackTimelineSteps(order)),
        data: (logs) {
          final steps = logs.isEmpty
              ? _fallbackTimelineSteps(order)
              : logs.map(_timelineStepFromLog).toList();
          return _TimelineStepList(steps: steps);
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

List<_TimelineStep> _fallbackTimelineSteps(OrderModel order) {
  final statusIndex = _statusOrder.indexOf(order.status);
  if (order.status == 'cancelled') {
    return [
      _TimelineStep(
        title: 'Đã tạo đơn',
        time: _formatOrderDateTime(order.createdAt),
        description: 'Đơn hàng đã được ghi nhận trong hệ thống.',
        done: true,
      ),
      _TimelineStep(
        title: 'Đã huỷ',
        time: _formatOrderDateTime(_bestStatusTime(order)),
        description: order.statusNote?.trim().isNotEmpty ?? false
            ? order.statusNote!.trim()
            : 'Đơn hàng đã bị huỷ.',
        done: true,
      ),
    ];
  }

  return List.generate(_statusOrder.length, (index) {
    final status = _statusOrder[index];
    final done = statusIndex >= index;
    final time = done
        ? _formatOrderDateTime(_timeForStatus(order, status))
        : 'Chưa cập nhật';
    return _TimelineStep(
      title: _statusLabel(status),
      time: time,
      description: _statusDescription(status, done),
      done: done,
    );
  });
}

_TimelineStep _timelineStepFromLog(OrderStatusLogModel log) {
  return _TimelineStep(
    title: log.title.isEmpty ? _statusLabel(log.status) : log.title,
    time: _formatOrderDateTime(log.createdAt),
    description: log.description?.trim().isNotEmpty ?? false
        ? log.description!.trim()
        : _statusDescription(log.status, true),
    done: true,
  );
}

DateTime _timeForStatus(OrderModel order, String status) {
  return switch (status) {
    'pending' => order.createdAt,
    'picking_up' => order.actualPickedUpAt ?? _bestStatusTime(order),
    'delivered' => order.actualDeliveredAt ?? _bestStatusTime(order),
    _ => _bestStatusTime(order),
  };
}

DateTime _bestStatusTime(OrderModel order) {
  if (order.updatedAt.millisecondsSinceEpoch > 0) return order.updatedAt;
  return order.createdAt;
}

String _formatOrderDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final hour = twoDigits(value.hour);
  final minute = twoDigits(value.minute);
  final day = twoDigits(value.day);
  final month = twoDigits(value.month);
  return '$hour:$minute · $day/$month/${value.year}';
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Đơn hàng đã đặt',
    'confirmed' => 'Đã xác nhận',
    'assigned' => 'Đã phân công tài xế',
    'picking_up' => 'Đang lấy hàng',
    'delivering' => 'Đang giao hàng',
    'delivered' => 'Giao hàng thành công',
    'cancelled' => 'Đã huỷ',
    _ => 'Không rõ',
  };
}

String _statusDescription(String status, bool done) {
  if (!done) {
    return 'Trạng thái này sẽ được cập nhật khi đơn hàng tiếp tục xử lý.';
  }

  return switch (status) {
    'pending' => 'Đơn hàng đã được tạo và đang chờ xác nhận.',
    'confirmed' => 'Đơn hàng đã được xác nhận.',
    'assigned' => 'Tài xế đã được phân công cho đơn hàng.',
    'picking_up' => 'Tài xế đang đến điểm lấy hàng.',
    'delivering' => 'Đơn hàng đang trên đường giao đến bạn.',
    'delivered' => 'Đơn hàng đã được giao thành công.',
    'cancelled' => 'Đơn hàng đã bị huỷ.',
    _ => 'Trạng thái đơn hàng đã được cập nhật.',
  };
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

String _joinNonEmpty(List<String?> values) {
  return values
      .map((value) => value?.trim() ?? '')
      .where((value) => value.isNotEmpty)
      .join(' · ');
}

const List<String> _statusOrder = [
  'pending',
  'confirmed',
  'assigned',
  'picking_up',
  'delivering',
  'delivered',
];
