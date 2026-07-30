import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/constants/app_theme.dart';
import '../../../../../../core/models/order_item_model.dart';
import '../../../../../../core/models/order_model.dart';
import '../../../../../../core/providers/customer_providers.dart';
import '../../../../../../core/utils/text_encoding_utils.dart';
import '../../order_helpers.dart';
import '../order_detail_strings.dart';
import 'order_detail_header.dart';
import 'order_detail_information.dart';

class OrderDetailItemsSection extends ConsumerWidget {
  const OrderDetailItemsSection({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(orderItemsProvider(orderId));

    return OrderDetailSectionSurface(
      title: OrderDetailStrings.itemsTitle,
      icon: Icons.inventory_2_outlined,
      child: itemsAsync.when(
        loading: () =>
            const _InlineLoading(label: OrderDetailStrings.itemsLoading),
        error: (_, _) => const _InlineMessage(
          icon: Icons.inventory_2_outlined,
          message: OrderDetailStrings.itemsLoadError,
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _InlineMessage(
              icon: Icons.inventory_2_outlined,
              message: OrderDetailStrings.noItems,
            );
          }
          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _OrderItemRow(item: items[index]),
                if (index != items.length - 1)
                  const Divider(height: AppSpacing.xl, color: AppColors.border),
              ],
            ],
          );
        },
      ),
    );
  }
}

class OrderDetailTimelineSection extends ConsumerWidget {
  const OrderDetailTimelineSection({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(orderStatusLogsProvider(order.id));

    return OrderDetailSectionSurface(
      title: OrderDetailStrings.timelineTitle,
      icon: Icons.route_rounded,
      child: logsAsync.when(
        loading: () =>
            const _InlineLoading(label: OrderDetailStrings.timelineLoading),
        error: (_, _) => _FallbackTimeline(order: order),
        data: (logs) {
          if (logs.isEmpty) return _FallbackTimeline(order: order);
          return Column(
            children: [
              for (var index = 0; index < logs.length; index++)
                _TimelineRow(
                  title: _safeTimelineTitle(
                    logs[index].status,
                    logs[index].displayTitle,
                  ),
                  description: _safeTimelineDescription(
                    logs[index].status,
                    logs[index].displayDescription,
                  ),
                  time: formatOrderDateTime(logs[index].createdAt),
                  status: logs[index].status,
                  isLast: index == logs.length - 1,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItemModel item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(
            Icons.local_mall_outlined,
            color: AppColors.accent,
            size: 19,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name.trim().isEmpty
                    ? OrderDetailStrings.cargoFallback
                    : item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Số lượng: ${item.quantity}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          formatOrderMoney(item.price),
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FallbackTimeline extends StatelessWidget {
  const _FallbackTimeline({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final steps = fallbackTimelineSteps(order);
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineRow(
            title: steps[index].title,
            description: steps[index].description,
            time: steps[index].time,
            status: steps[index].status,
            isLast: index == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.description,
    required this.time,
    required this.status,
    required this.isLast,
  });

  final String title;
  final String? description;
  final String time;
  final String status;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final statusView = OrderStatusView.fromStatus(status);
    final detail = description?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusView.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusView.color.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(statusView.icon, size: 16, color: statusView.color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 54,
                color: AppColors.accent.withValues(alpha: 0.18),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      time,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
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

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(
            Icons.more_horiz_rounded,
            color: AppColors.accent,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
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
  const _InlineMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
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

String _safeTimelineTitle(String status, String value) {
  final text = value.trim();
  if (text.isNotEmpty && !containsUtf8Mojibake(text)) return text;

  return switch (status) {
    'pending' => 'Đã tạo đơn',
    'confirmed' => 'Đã xác nhận',
    'assigned' => 'Tài xế đã nhận đơn',
    'picking_up' => 'Tài xế đang lấy hàng',
    'delivering' => 'Đơn hàng đang được giao',
    'delivered' => 'Giao hàng thành công',
    'cancelled' => 'Đã hủy đơn',
    _ => OrderStatusView.fromStatus(status).label,
  };
}

String? _safeTimelineDescription(String status, String? value) {
  final text = value?.trim();
  if (text != null && text.isNotEmpty && !containsUtf8Mojibake(text)) {
    return text;
  }

  return switch (status) {
    'pending' => 'Đơn hàng đã được tạo và đang chờ tài xế nhận.',
    'confirmed' => 'Đơn hàng đã được xác nhận.',
    'assigned' => 'Tài xế đã nhận đơn và đang đến điểm lấy hàng.',
    'picking_up' => 'Tài xế đang lấy hàng tại điểm gửi.',
    'delivering' => 'Tài xế đang giao hàng đến người nhận.',
    'delivered' => 'Đơn hàng đã được giao thành công.',
    'cancelled' => 'Đơn hàng đã bị hủy.',
    _ => null,
  };
}
