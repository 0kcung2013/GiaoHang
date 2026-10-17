import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../driver_home_strings.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_incoming_offer_finance.dart';
import 'driver_order_offer_summary.dart';

class DriverIncomingOfferPresentation extends StatelessWidget {
  const DriverIncomingOfferPresentation({
    super.key,
    required this.order,
    required this.actions,
    this.driverId,
    this.driverPosition,
  });

  final OrderModel order;
  final String? driverId;
  final LatLng? driverPosition;
  final Widget actions;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: AppColors.bgCard,
      systemNavigationBarColor: AppColors.bgCard,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: PopScope(
      canPop: false,
      child: Scaffold(
        key: const ValueKey('driver-incoming-offer-overlay'),
        backgroundColor: AppColors.bgCard,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('driver-incoming-offer-scroll'),
                      padding: const EdgeInsets.all(AppSpacing.screenH),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            liveRegion: true,
                            label: DriverHomeStrings.incomingOfferSemantic(
                              displayOrderCode(order),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentLight,
                                    borderRadius: AppRadius.lg,
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DriverHomeStrings.incomingOfferTitle,
                                        style: AppTextStyles.headingLarge
                                            .copyWith(color: AppColors.primary),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        displayOrderCode(order),
                                        style: AppTextStyles.mono.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl2),
                          Text(
                            DriverHomeStrings.incomingOfferEarning,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            formatVnd(order.driverNetEarning),
                            key: const ValueKey(
                              'driver-incoming-offer-earning',
                            ),
                            style: AppTextStyles.displayLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          DriverIncomingOfferFinance(order: order),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          DriverOrderRouteSummary(
                            order: order,
                            driverId: driverId,
                            driverPosition: driverPosition,
                            prominentAddresses: true,
                            showEstimatedTimes: true,
                            compactDistance: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.bgCard,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: actions,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
