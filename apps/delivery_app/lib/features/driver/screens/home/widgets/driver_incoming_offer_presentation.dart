import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../driver_home_strings.dart';
import '../utils/driver_home_formatters.dart';
import '../utils/driver_order_distance.dart';
import 'driver_offer_countdown.dart';
import 'driver_order_offer_summary.dart';

class DriverIncomingOfferPresentation extends StatelessWidget {
  const DriverIncomingOfferPresentation({
    super.key,
    required this.order,
    required this.actions,
    this.pickupDistanceMeters,
    this.now,
  });

  final OrderModel order;
  final double? pickupDistanceMeters;
  final DateTime Function()? now;
  final Widget actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('driver-incoming-offer-overlay'),
    backgroundColor: AppColors.bgDark,
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Semantics(
              liveRegion: true,
              label: DriverHomeStrings.incomingOfferSemantic(
                displayOrderCode(order),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DriverHomeStrings.incomingOfferTitle,
                    style: AppTextStyles.headingLarge.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl2),
                  DriverOfferEarning(
                    amount: order.driverNetEarning,
                    dark: true,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      displayOrderCode(order),
                      style: AppTextStyles.mono.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl2),
                    DriverOrderRouteSummary(
                      order: order,
                      totalDistanceMeters: totalOrderDistanceFromPickup(
                        order: order,
                        pickupDistanceMeters: pickupDistanceMeters,
                      ),
                    ),
                    if (order.offerExpiresAt != null) ...[
                      const SizedBox(height: AppSpacing.xl2),
                      DriverOfferCountdown(
                        expiresAt:
                            order.offerExpiresAt!.isBefore(
                              order.assignmentDeadline,
                            )
                            ? order.offerExpiresAt!
                            : order.assignmentDeadline,
                        now: now,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            color: AppColors.bgCard,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: actions,
            ),
          ),
        ],
      ),
    ),
  );
}
