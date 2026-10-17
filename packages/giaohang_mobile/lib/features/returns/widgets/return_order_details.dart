import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import '../../driver/widgets/driver_swipe_action.dart';
import '../utils/return_navigation_strings.dart';

class ReturnOrderDetails extends StatelessWidget {
  const ReturnOrderDetails({
    required this.order,
    required this.mission,
    required this.showPickup,
    required this.onSelectPickup,
    required this.onOpenMap,
    super.key,
  });

  final OrderModel order;
  final OrderReturn mission;
  final bool showPickup;
  final ValueChanged<bool> onSelectPickup;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final color = showPickup ? AppColors.markerPickup : AppColors.markerDrop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.lg,
          ),
          child: Row(
            children: [
              _tab(ReturnNavigationStrings.pickupTab, true),
              const SizedBox(width: AppSpacing.sm),
              _tab(ReturnNavigationStrings.deliveryTab, false),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.xl,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    showPickup
                        ? Icons.keyboard_return_rounded
                        : Icons.location_on_rounded,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      showPickup
                          ? ReturnNavigationStrings.returnPoint
                          : ReturnNavigationStrings.deliveryPoint,
                      style: AppTextStyles.labelMedium.copyWith(color: color),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const Key('return-open-map'),
                    onPressed: onOpenMap,
                    tooltip: ReturnNavigationStrings.openMap,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: color.withValues(alpha: 0.1),
                      foregroundColor: color,
                    ),
                    icon: const Icon(Icons.map_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                showPickup ? mission.destinationAddress : order.deliveryAddress,
                style: AppTextStyles.headingMedium,
              ),
              if (!showPickup && order.recipientName?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.lg),
                _detail(
                  ReturnNavigationStrings.recipient,
                  order.recipientName!,
                ),
                if (order.recipientPhone?.isNotEmpty == true)
                  Text(order.recipientPhone!, style: AppTextStyles.bodyMedium),
              ],
              if (showPickup && mission.instruction?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.lg),
                _detail(ReturnNavigationStrings.note, mission.instruction!),
              ],
            ],
          ),
        ),
        if (order.itemName?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.xl),
          _detail(ReturnNavigationStrings.goods, order.itemName!),
          if (order.itemDescription?.isNotEmpty == true)
            Text(order.itemDescription!, style: AppTextStyles.bodyMedium),
        ],
        if (order.note?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.lg),
          _detail(ReturnNavigationStrings.note, order.note!),
        ],
        if (!showPickup) ...[
          const SizedBox(height: AppSpacing.xl),
          const DriverSwipeAction(
            key: Key('return-delivery-disabled'),
            label: ReturnNavigationStrings.swipeDelivered,
            accent: AppColors.accent,
            icon: Icons.check_circle_rounded,
            onCompleted: null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ReturnNavigationStrings.deliveryLocked,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tab(String label, bool pickup) {
    final selected = showPickup == pickup;
    return Expanded(
      child: TextButton(
        key: Key(pickup ? 'return-pickup-tab' : 'return-delivery-tab'),
        onPressed: () => onSelectPickup(pickup),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: selected ? AppColors.primary : AppColors.bgCard,
          foregroundColor: selected
              ? AppColors.textOnDark
              : AppColors.textSecondary,
          textStyle: AppTextStyles.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
        child: Semantics(selected: selected, child: Text(label)),
      ),
    );
  }

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: AppTextStyles.bodyLarge),
    ],
  );
}
