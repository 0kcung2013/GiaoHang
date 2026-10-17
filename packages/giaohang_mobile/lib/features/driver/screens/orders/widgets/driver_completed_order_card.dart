import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../../../../reviews/widgets/driver_rate_customer_sheet.dart';
import '../../home/utils/driver_home_formatters.dart';
import '../dialogs/driver_completed_order_detail_sheet.dart';
import '../utils/driver_orders_strings.dart';

class DriverCompletedOrderCard extends ConsumerWidget {
  const DriverCompletedOrderCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = order.driverNetEarning > 0
        ? order.driverNetEarning
        : order.deliveryFee.round();

    return Semantics(
      button: true,
      label:
          '${DriverOrdersStrings.detailTitle} ${displayOrderCode(order)}, '
          '${DriverOrdersStrings.completedLabel}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('driver-completed-order-${order.id}'),
          borderRadius: AppRadius.lg,
          onTap: () => showDriverCompletedOrderDetailSheet(
            context: context,
            order: order,
            onRateCustomer: () => _rateCustomer(context, ref),
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.subtle,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  color: AppColors.bgWarm,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayOrderCode(order),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.headingSmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              formatVnd(income),
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: AppRadius.full,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_shipping_rounded,
                              color: AppColors.accent,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              serviceTypeLabel(order.serviceType),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      _CompletedRouteRow(
                        icon: Icons.storefront_rounded,
                        color: AppColors.markerPickup,
                        label: DriverOrdersStrings.pickupLabel,
                        address: order.pickupAddress,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      _CompletedRouteRow(
                        icon: Icons.location_on_rounded,
                        color: AppColors.markerDrop,
                        label: DriverOrdersStrings.deliveryLabel,
                        address: order.deliveryAddress,
                      ),
                      if ((order.note ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.bgWarm,
                            borderRadius: AppRadius.md,
                          ),
                          child: Text(
                            order.note!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${DriverOrdersStrings.completedLabel} lúc '
                              '${deliveredTimeText(order)}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                            size: 24,
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
      ),
    );
  }

  Future<void> _rateCustomer(BuildContext context, WidgetRef ref) async {
    final existing = await ref.read(
      driverCustomerReviewProvider(order.id).future,
    );
    if (!context.mounted) return;
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bạn đã đánh giá khách ${existing.rating}/5 cho đơn này.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await showDriverRateCustomerSheet(context: context, order: order);
    ref.invalidate(driverCustomerReviewProvider(order.id));
  }
}

class _CompletedRouteRow extends StatelessWidget {
  const _CompletedRouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
