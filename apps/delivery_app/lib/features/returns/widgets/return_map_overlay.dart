import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/utils/delivery_map_utils.dart';
import '../models/return_map_snapshot.dart';
import '../utils/return_navigation_strings.dart';

/// Các controls nhỏ để dành phần lớn diện tích cho bản đồ.
class ReturnMapOverlay extends StatelessWidget {
  const ReturnMapOverlay({
    required this.state,
    required this.isReturnRoute,
    required this.previewFailed,
    required this.loading,
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.onBack,
    required this.onStart,
    required this.onFollow,
    required this.onRetry,
    super.key,
  });
  final ReturnMapSnapshot state;
  final bool isReturnRoute;
  final bool previewFailed;
  final bool loading;
  final double? distance;
  final double? duration;
  final String instruction;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final VoidCallback onFollow;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned(
        top: 0,
        left: AppSpacing.md,
        right: AppSpacing.md,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _control(
                  Icons.arrow_back_rounded,
                  ReturnNavigationStrings.back,
                  onBack,
                  key: const Key('return-map-back'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: AppRadius.lg,
                      boxShadow: AppShadow.subtle,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelLarge,
                        ),
                        if (loading)
                          Text(
                            ReturnNavigationStrings.loadingRoute,
                            style: AppTextStyles.bodySmall,
                          )
                        else if (distance != null)
                          Text(
                            '${DeliveryMapUtils.formatDistance(distance!)}${duration == null ? '' : ' · ${DeliveryMapUtils.formatDuration(duration!)}'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (previewFailed || (isReturnRoute && state.error != null))
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: const BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: AppRadius.md,
                    ),
                    child: Text(
                      previewFailed
                          ? ReturnNavigationStrings.routeError
                          : state.error!,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: isReturnRoute
                            ? Tooltip(
                                message: state.canStart || state.arrived
                                    ? ReturnNavigationStrings.startGps
                                    : ReturnNavigationStrings.startReturnFirst,
                                child: FilledButton.icon(
                                  key: const Key('return-map-start'),
                                  onPressed:
                                      state.canStart &&
                                          !state.running &&
                                          !loading
                                      ? onStart
                                      : null,
                                  icon: Icon(
                                    state.arrived
                                        ? Icons.check_rounded
                                        : state.running
                                        ? Icons.navigation_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    state.arrived
                                        ? ReturnNavigationStrings.gpsArrived
                                        : state.running
                                        ? ReturnNavigationStrings.gpsRunning
                                        : ReturnNavigationStrings.startGps,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: FilledButton.styleFrom(
                                    textStyle: AppTextStyles.labelMedium,
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.textOnDark,
                                    disabledBackgroundColor: AppColors.bgCard,
                                    disabledForegroundColor:
                                        AppColors.textSecondary,
                                    minimumSize: const Size(88, 48),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: AppRadius.full,
                                    ),
                                  ),
                                ),
                              )
                            : previewFailed
                            ? TextButton(
                                onPressed: onRetry,
                                child: const Text(
                                  ReturnNavigationStrings.retry,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _control(
                      Icons.my_location_rounded,
                      ReturnNavigationStrings.followPosition,
                      onFollow,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ReturnNavigationStrings.osmAttribution,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _control(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    Key? key,
  }) => Material(
    color: AppColors.bgCard,
    borderRadius: AppRadius.full,
    elevation: 2,
    child: IconButton(
      key: key,
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Icon(icon, color: AppColors.primary),
    ),
  );
}
