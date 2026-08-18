import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/utils/delivery_map_utils.dart';
import '../../driver/widgets/driver_swipe_action.dart';
import '../utils/return_completion_guard.dart';
import '../utils/return_navigation_strings.dart';

class ReturnBottomPanel extends StatelessWidget {
  const ReturnBottomPanel({
    required this.mission,
    required this.loading,
    required this.submitting,
    required this.distance,
    required this.duration,
    required this.handoffDistance,
    required this.error,
    required this.onRefresh,
    required this.onAction,
    super.key,
  });

  final OrderReturn mission;
  final bool loading;
  final bool submitting;
  final double? distance;
  final double? duration;
  final double? handoffDistance;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final approved = mission.status == OrderReturnStatus.approved;
    final canComplete = ReturnCompletionGuard.canComplete(handoffDistance);
    final actionEnabled = !loading && !submitting;

    return Material(
      key: const Key('return-bottom-panel'),
      color: AppColors.bgCard,
      elevation: 16,
      shadowColor: AppColors.primary.withValues(alpha: 0.22),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.sm,
                    ),
                    child: const Icon(
                      Icons.keyboard_return_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          approved
                              ? ReturnNavigationStrings.readyPanelTitle
                              : ReturnNavigationStrings.returningPanelTitle,
                          style: AppTextStyles.headingSmall,
                        ),
                        Text(
                          mission.destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  _MetricItem(
                    icon: Icons.route_rounded,
                    label: distance == null
                        ? ReturnNavigationStrings.loadingDistance
                        : DeliveryMapUtils.formatDistance(distance!),
                  ),
                  if (duration != null)
                    _MetricItem(
                      icon: Icons.schedule_rounded,
                      label: DeliveryMapUtils.formatDuration(duration!),
                    ),
                  _MetricItem(
                    icon: Icons.payments_rounded,
                    label: '+${formatVnd(mission.driverReturnEarning)}',
                    foreground: AppColors.success,
                  ),
                ],
              ),
              if (!approved && !canComplete) ...[
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const Key('return-geofence-guidance'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: AppRadius.md,
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            ReturnCompletionGuard.compactBlockedMessage(
                              handoffDistance,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  IconButton.outlined(
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: loading ? null : onRefresh,
                    tooltip: ReturnNavigationStrings.refreshRoute,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DriverSwipeAction(
                      key: const Key('return-primary-action'),
                      label: approved
                          ? ReturnNavigationStrings.swipeStartReturn
                          : ReturnNavigationStrings.swipeConfirmHandoff,
                      accent: approved ? AppColors.accent : AppColors.primary,
                      icon: approved
                          ? Icons.navigation_rounded
                          : Icons.inventory_2_rounded,
                      loading: loading || submitting,
                      onCompleted: actionEnabled ? onAction : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.label,
    this.foreground = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
