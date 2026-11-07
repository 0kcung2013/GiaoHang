import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../../core/models/order_model.dart';
import '../../../core/providers/driver_task_priority_provider.dart';
import 'recipient_hold_strings.dart';
import '../screens/home/utils/driver_home_formatters.dart';
import '../screens/navigation/driver_accepted_order_screen.dart';

/// Compact companion to the held parcel; one dominant action on the dashboard.
class DriverWorkingOrderCard extends ConsumerWidget {
  const DriverWorkingOrderCard({
    super.key,
    required this.order,
    this.isPriority = true,
  });
  final OrderModel order;
  final bool isPriority;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    key: ValueKey('working-order-${order.id}'),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: isPriority ? AppColors.primary : AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: isPriority ? null : Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              order.status == 'delivering' &&
                      order.recipientHold?.state == 'resumed'
                  ? RecipientHoldStrings.redelivering
                  : statusLabel(order.status),
              style: AppTextStyles.labelLarge.copyWith(
                color: isPriority
                    ? AppColors.textOnDark
                    : AppColors.textPrimary,
              ),
            ),
            Text(
              displayOrderCode(order),
              style: AppTextStyles.mono.copyWith(
                color: isPriority
                    ? AppColors.textOnDark
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          order.status == 'delivering'
              ? order.deliveryAddress
              : order.pickupAddress,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(
            color: isPriority ? AppColors.textOnDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            textStyle: AppTextStyles.labelLarge,
            backgroundColor: isPriority ? AppColors.accent : AppColors.bgLight,
            foregroundColor: isPriority
                ? AppColors.textOnAccent
                : AppColors.primary,
            side: isPriority ? null : const BorderSide(color: AppColors.border),
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          ),
          onPressed: () {
            ref.read(driverPriorityOrderIdProvider.notifier).state = order.id;
            openDriverAcceptedOrder(context, order.id);
          },
          icon: const Icon(Icons.navigation_outlined),
          label: const Text('Tiếp tục đơn hàng'),
        ),
      ],
    ),
  );
}
