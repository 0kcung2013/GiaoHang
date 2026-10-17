import '../utils/order_hub_strings.dart';
import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../order_helpers.dart';
import '../utils/order_history_filter.dart';

class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({super.key, required this.order, required this.onTap});
  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = OrderStatusView.fromStatus(
      order.effectiveStatusAt(DateTime.now()),
    );
    final code = order.trackingCode.isNotEmpty
        ? order.trackingCode
        : '#${order.id.substring(0, order.id.length.clamp(0, 8))}';
    final price = order.totalPrice ?? order.deliveryFee;
    final priceText = price <= 0
        ? OrderHubStrings.noFee
        : '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
    return Semantics(
      button: true,
      label: 'Xem đơn $code, ${status.label}',
      child: Material(
        color: AppColors.bgCard,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(code, style: AppTextStyles.mono),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 16, color: status.color),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          status.label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _Address(
                  label: OrderHubStrings.pickup,
                  address: order.pickupAddress,
                  icon: Icons.my_location_rounded,
                  color: AppColors.markerPickup,
                ),
                const SizedBox(height: AppSpacing.sm),
                _Address(
                  label: OrderHubStrings.delivery,
                  address: order.deliveryAddress,
                  icon: Icons.location_on_rounded,
                  color: AppColors.markerDrop,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.recipientName?.trim().isNotEmpty == true
                            ? order.recipientName!
                            : OrderHubStrings.missingRecipient,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      orderHistoryDate(order.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      priceText,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Address extends StatelessWidget {
  const _Address({
    required this.label,
    required this.address,
    required this.icon,
    required this.color,
  });
  final String label;
  final String address;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          '$label · ${address.isEmpty ? OrderHubStrings.missingAddress : address}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        ),
      ),
    ],
  );
}
