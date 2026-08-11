import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../models/driver_delivery_workflow.dart';

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
    final canConfirm = workflow.canPerform(arrivedAtTarget: arrivedAtTarget);
    final enabled = canConfirm && !isLoading;
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: workflow.accent.withValues(alpha: 0.18),
              borderRadius: AppRadius.md,
            ),
            child: Icon(workflow.primaryIcon, color: workflow.accent, size: 24),
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
          const SizedBox(width: AppSpacing.sm),
          if (onContact != null) ...[
            Material(
              color: AppColors.bgDarkCard,
              borderRadius: AppRadius.full,
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                onPressed: onContact,
                tooltip: 'Liên hệ',
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.info,
                ),
                icon: const Icon(Icons.forum_rounded, size: 21),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Material(
            color: enabled ? workflow.accent : AppColors.bgDarkCard,
            borderRadius: AppRadius.full,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPrimaryAction : null,
              borderRadius: AppRadius.full,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Center(
                    child: isLoading
                        ? const Icon(
                            Icons.more_horiz_rounded,
                            color: AppColors.textOnAccent,
                          )
                        : Icon(
                            enabled
                                ? workflow.primaryIcon
                                : Icons.lock_outline_rounded,
                            size: 21,
                            color: enabled
                                ? AppColors.textOnAccent
                                : AppColors.textMuted,
                          ),
                  ),
                ),
              ),
            ),
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
