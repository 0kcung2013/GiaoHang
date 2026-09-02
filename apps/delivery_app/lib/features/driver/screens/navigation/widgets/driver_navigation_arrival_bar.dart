import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../widgets/driver_swipe_action.dart';
import '../models/driver_delivery_workflow.dart';
import '../utils/driver_navigation_strings.dart';

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
  });

  final OrderModel order;
  final bool arrivedAtTarget;
  final bool pickupConfirmed;
  final bool isLoading;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onContact;
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;

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
    final actionLabel = workflow.requiresArrival && !arrivedAtTarget
        ? DriverNavigationStrings.arriveToConfirm
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
        color: AppColors.primary.withValues(alpha: 0.97),
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.textOnDark.withValues(alpha: 0.1)),
        boxShadow: AppShadow.elevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: workflow.accent.withValues(alpha: 0.18),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  workflow.primaryIcon,
                  color: workflow.accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workflow.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textOnDark.withValues(alpha: 0.72),
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
                      color: AppColors.bgDarkCard,
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
                                color: AppColors.info,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                DriverNavigationStrings.contactAction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textOnDark,
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
            accent: workflow.accent,
            icon: workflow.primaryIcon,
            loading: isLoading,
            dark: true,
            onCompleted: enabled ? onPrimaryAction : null,
          ),
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
