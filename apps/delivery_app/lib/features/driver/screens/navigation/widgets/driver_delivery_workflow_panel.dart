import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../widgets/driver_swipe_action.dart';
import '../models/driver_delivery_workflow.dart';
import '../utils/driver_navigation_strings.dart';

class DriverDeliveryWorkflowPanel extends StatelessWidget {
  const DriverDeliveryWorkflowPanel({
    super.key,
    required this.order,
    required this.arrivedAtTarget,
    required this.isLoading,
    required this.onPrimaryAction,
    this.pickupConfirmed = false,
    this.scrollController,
    this.remainingDistanceMeters,
    this.remainingDurationSeconds,
    this.onCallRecipient,
  });

  final OrderModel order;
  final bool arrivedAtTarget;
  final bool isLoading;
  final VoidCallback? onPrimaryAction;
  final bool pickupConfirmed;
  final ScrollController? scrollController;
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;
  final VoidCallback? onCallRecipient;

  @override
  Widget build(BuildContext context) {
    final workflow = DriverDeliveryWorkflow.fromStatus(
      order.status,
      pickupConfirmed: pickupConfirmed,
    );
    final isDelivery =
        workflow.action == DriverDeliveryAction.startDelivery ||
        workflow.action == DriverDeliveryAction.confirmDelivery;
    final address = isDelivery ? order.deliveryAddress : order.pickupAddress;
    final actionEnabled =
        workflow.canPerform(arrivedAtTarget: arrivedAtTarget) && !isLoading;
    final actionLabel = workflow.requiresArrival && !arrivedAtTarget
        ? DriverNavigationStrings.arriveToConfirm
        : workflow.primaryLabel;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadow.elevated,
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DeliveryProgress(
              currentStep: workflow.stepIndex,
              accent: workflow.accent,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: workflow.accent.withValues(alpha: 0.12),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(
                    workflow.primaryIcon,
                    color: workflow.accent,
                    size: 23,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workflow.eyebrow,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: workflow.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        workflow.title,
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (arrivedAtTarget && workflow.requiresArrival)
                  const _ArrivalBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _DestinationCard(
              address: address,
              isDelivery: isDelivery,
              recipientName: order.recipientName,
              recipientPhone: order.recipientPhone,
              remainingDistanceMeters: remainingDistanceMeters,
              remainingDurationSeconds: remainingDurationSeconds,
              onCallRecipient: isDelivery ? onCallRecipient : null,
            ),
            const SizedBox(height: AppSpacing.md),
            if (workflow.requiresArrival && !arrivedAtTarget)
              const _ProofLocationHint(),
            if (workflow.requiresArrival && !arrivedAtTarget)
              const SizedBox(height: AppSpacing.sm),
            DriverSwipeAction(
              label: actionLabel,
              accent: workflow.accent,
              icon: workflow.primaryIcon,
              loading: isLoading,
              onCompleted: actionEnabled ? onPrimaryAction : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress({required this.currentStep, required this.accent});

  final int currentStep;
  final Color accent;

  static const _labels = ['Nhận đơn', 'Lấy hàng', 'Giao hàng', 'Hoàn tất'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (index) {
        final completed = index < currentStep;
        final active = index == currentStep;
        final color = completed
            ? AppColors.success
            : active
            ? accent
            : AppColors.border;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: AppDuration.normal,
                      width: active ? 24 : 20,
                      height: active ? 24 : 20,
                      decoration: BoxDecoration(
                        color: completed || active ? color : AppColors.bgCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: completed
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AppColors.textOnAccent,
                            )
                          : active
                          ? Container(
                              margin: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.textOnAccent,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _labels[index],
                      maxLines: 1,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: completed || active
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < _labels.length - 1)
                Container(
                  width: 18,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: index < currentStep
                      ? AppColors.success
                      : AppColors.border,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.address,
    required this.isDelivery,
    required this.recipientName,
    required this.recipientPhone,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.onCallRecipient,
  });

  final String address;
  final bool isDelivery;
  final String? recipientName;
  final String? recipientPhone;
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;
  final VoidCallback? onCallRecipient;

  @override
  Widget build(BuildContext context) {
    final accent = isDelivery ? AppColors.markerDrop : AppColors.markerPickup;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isDelivery ? Icons.location_on_rounded : Icons.storefront_rounded,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDelivery && recipientName?.trim().isNotEmpty == true)
                  Text(
                    recipientName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (remainingDistanceMeters != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${DeliveryMapUtils.formatDistance(remainingDistanceMeters!)}'
                    '${remainingDurationSeconds == null ? '' : ' • ≈ ${DeliveryMapUtils.formatDuration(remainingDurationSeconds!)}'}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCallRecipient != null &&
              recipientPhone?.trim().isNotEmpty == true)
            IconButton(
              onPressed: onCallRecipient,
              tooltip: 'Gọi người nhận',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                foregroundColor: AppColors.success,
              ),
              icon: const Icon(Icons.call_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

class _ProofLocationHint extends StatelessWidget {
  const _ProofLocationHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_searching_rounded,
          size: 17,
          color: AppColors.warning,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            DriverNavigationStrings.swipeProofHint,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrivalBadge extends StatelessWidget {
  const _ArrivalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        'Đã đến',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
