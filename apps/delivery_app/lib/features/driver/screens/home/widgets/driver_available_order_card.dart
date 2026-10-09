import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../utils/driver_home_formatters.dart';
import '../utils/driver_order_distance.dart';
import 'driver_offer_countdown.dart';
import 'driver_order_offer_summary.dart';

class DriverAvailableOrderCard extends StatelessWidget {
  const DriverAvailableOrderCard({
    super.key,
    required this.order,
    required this.actions,
    this.pickupDistanceMeters,
    this.now,
  });

  final OrderModel order;
  final double? pickupDistanceMeters;
  final DateTime Function()? now;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DriverOrderPresentationStrings.newOrder,
          style: AppTextStyles.headingMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        DriverOfferEarning(amount: order.driverNetEarning),
        const Divider(height: AppSpacing.xl3, color: AppColors.border),
        DriverOrderRouteSummary(
          order: order,
          totalDistanceMeters: totalOrderDistanceFromPickup(
            order: order,
            pickupDistanceMeters: pickupDistanceMeters,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          displayOrderCode(order),
          style: AppTextStyles.mono.copyWith(color: AppColors.textSecondary),
        ),
        if (order.offerExpiresAt != null) ...[
          const SizedBox(height: AppSpacing.lg),
          DriverOfferCountdown(
            expiresAt: order.offerExpiresAt!.isBefore(order.assignmentDeadline)
                ? order.offerExpiresAt!
                : order.assignmentDeadline,
            now: now,
          ),
        ],
        if (actions != null) ...[
          const SizedBox(height: AppSpacing.lg),
          actions!,
        ],
      ],
    ),
  );
}
