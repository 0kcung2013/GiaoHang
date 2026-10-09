import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../widgets/driver_swipe_action.dart';
import '../models/driver_delivery_workflow.dart';
import '../utils/driver_navigation_strings.dart';
import '../../../cancellation/driver_cancellation_strings.dart';
import 'driver_delivery_countdown.dart';
import '../models/driver_delivery_arrival.dart';
import '../utils/driver_delivery_arrival_strings.dart';

/// Thanh tác vụ gọn cho màn điều hướng: map luôn được ưu tiên diện tích.
class DriverNavigationArrivalBar extends StatelessWidget {
  const DriverNavigationArrivalBar({
    super.key,
    required this.order,
    required this.arrivedAtTarget,
    required this.pickupConfirmed,
    required this.isLoading,
    required this.onPrimaryAction,
    this.onContact,
    this.remainingDistanceMeters,
    this.remainingDurationSeconds,
    this.onConfirmPickupArrival,
    this.deliveryArrival,
    this.deliveryWait,
    this.onConfirmDeliveryArrival,
    this.onReportRecipient,
    this.arrivalError,
    this.onRetryArrival,
  });

  final OrderModel order;
  final bool arrivedAtTarget;
  final bool pickupConfirmed;
  final bool isLoading;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onContact;
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;
  final VoidCallback? onConfirmPickupArrival;
  final DriverDeliveryArrival? deliveryArrival;
  final Duration? deliveryWait;
  final VoidCallback? onConfirmDeliveryArrival;
  final VoidCallback? onReportRecipient;
  final String? arrivalError;
  final VoidCallback? onRetryArrival;

  @override
  Widget build(BuildContext context) {
    final workflow = DriverDeliveryWorkflow.fromStatus(
      order.status,
      pickupConfirmed: pickupConfirmed,
    );
    final enabled =
        workflow.canPerform(arrivedAtTarget: arrivedAtTarget) &&
        !isLoading &&
        onPrimaryAction != null;
    final confirmingArrival =
        order.status == 'picking_up' &&
        !pickupConfirmed &&
        order.pickupArrivedAt == null &&
        onConfirmPickupArrival != null;
    final deliveryArrivalFlow =
        order.status == 'delivering' && onConfirmDeliveryArrival != null;
    final confirmingDeliveryArrival =
        deliveryArrivalFlow && deliveryArrival?.arrivedAt == null;
    final actionLabel = confirmingDeliveryArrival
        ? DriverDeliveryArrivalStrings.swipeArrival
        : workflow.requiresArrival && !arrivedAtTarget
        ? DriverNavigationStrings.arriveToConfirm
        : confirmingArrival
        ? DriverCancellationStrings.swipeArrived
        : workflow.primaryLabel;
    final progress = pickupConfirmed
        ? 'Sẵn sàng giao hàng'
        : arrivedAtTarget
        ? 'Bạn đã đến điểm dừng'
        : _remainingLabel();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!deliveryArrivalFlow)
                      Text(
                        workflow.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (!deliveryArrivalFlow) const SizedBox(height: 2),
                    if (const {
                      'assigned',
                      'picking_up',
                      'delivering',
                    }.contains(order.status))
                      DriverDeliveryCountdown(
                        key: ValueKey('delivery-countdown-${order.id}'),
                        deadline: order.estimatedDeliveryAt,
                        compact: true,
                        dark: false,
                      )
                    else
                      Text(
                        progress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
              if (onContact != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  button: true,
                  label: workflow.contactActionTooltip,
                  child: Tooltip(
                    message: workflow.contactActionTooltip,
                    child: Material(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.full,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('driver-contact-target-action'),
                        onTap: onContact,
                        borderRadius: AppRadius.full,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.contact_phone_rounded,
                                color: AppColors.accent,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                DriverNavigationStrings.contactAction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DriverSwipeAction(
            key: const Key('driver-navigation-primary-action'),
            label: actionLabel,
            accent: AppColors.accent,
            icon: confirmingDeliveryArrival
                ? Icons.location_on_rounded
                : workflow.primaryIcon,
            loading: isLoading,
            onCompleted: confirmingDeliveryArrival
                ? (arrivedAtTarget &&
                          !isLoading &&
                          deliveryArrival != null &&
                          arrivalError == null
                      ? onConfirmDeliveryArrival
                      : null)
                : enabled
                ? (confirmingArrival ? onConfirmPickupArrival : onPrimaryAction)
                : null,
          ),
          if (deliveryArrivalFlow) ...[
            const SizedBox(height: AppSpacing.xs),
            if (deliveryArrival == null || arrivalError != null)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : onRetryArrival,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      minimumSize: const Size(48, 48),
                      textStyle: AppTextStyles.labelMedium,
                    ),
                    child: Text(
                      arrivalError ?? DriverDeliveryArrivalStrings.loading,
                    ),
                  ),
                  TextButton(
                    onPressed: enabled ? onPrimaryAction : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size(48, 48),
                      textStyle: AppTextStyles.labelMedium,
                    ),
                    child: const Text(DriverDeliveryArrivalStrings.deliverNow),
                  ),
                ],
              )
            else if (deliveryArrival!.arrivedAt == null)
              TextButton(
                onPressed: enabled ? onPrimaryAction : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(48, 48),
                  textStyle: AppTextStyles.labelMedium,
                ),
                child: const Text(DriverDeliveryArrivalStrings.deliverNow),
              )
            else
              TextButton.icon(
                key: const Key('driver-report-recipient-action'),
                onPressed: deliveryArrival!.canReport && !isLoading
                    ? onReportRecipient
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  disabledForegroundColor: AppColors.textSecondary,
                  minimumSize: const Size(48, 48),
                  textStyle: AppTextStyles.labelMedium,
                ),
                icon: Icon(
                  deliveryArrival!.canReport
                      ? Icons.phone_disabled_rounded
                      : Icons.lock_clock_rounded,
                  size: 20,
                ),
                label: Text(
                  deliveryArrival!.canReport
                      ? DriverDeliveryArrivalStrings.reportRecipient
                      : '${DriverDeliveryArrivalStrings.remaining(deliveryWait ?? Duration.zero)} · Báo sự cố',
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _remainingLabel() {
    final distance = remainingDistanceMeters;
    if (distance == null) return 'Đang xác định vị trí';
    final duration = remainingDurationSeconds;
    final time = duration == null
        ? ''
        : ' · ${DeliveryMapUtils.formatDuration(duration)}';
    return 'Còn ${DeliveryMapUtils.formatDistance(distance)}$time';
  }
}
