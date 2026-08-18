import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/services/osrm_service.dart';
import '../../../core/utils/delivery_map_utils.dart';
import '../../driver/screens/navigation/models/driver_position_source.dart';
import '../utils/return_navigation_strings.dart';

class ReturnNavigationHeader extends StatelessWidget {
  const ReturnNavigationHeader({
    required this.isApproved,
    required this.navigationStep,
    required this.maneuverDistance,
    required this.remainingDistance,
    required this.remainingDuration,
    required this.positionSource,
    required this.onBack,
    required this.onFollowPosition,
    super.key,
  });

  final bool isApproved;
  final OsrmNavigationStep? navigationStep;
  final double? maneuverDistance;
  final double? remainingDistance;
  final double? remainingDuration;
  final DriverPositionSource positionSource;
  final VoidCallback onBack;
  final VoidCallback onFollowPosition;

  @override
  Widget build(BuildContext context) {
    final title = isApproved
        ? ReturnNavigationStrings.readyTitle
        : navigationStep?.instruction ?? ReturnNavigationStrings.fallbackTitle;
    final distance = isApproved ? remainingDistance : maneuverDistance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _MapControlButton(
                icon: Icons.arrow_back_rounded,
                tooltip: ReturnNavigationStrings.back,
                onPressed: onBack,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: _ReturnStatusPill()),
              const SizedBox(width: AppSpacing.sm),
              _MapControlButton(
                icon: Icons.my_location_rounded,
                tooltip: ReturnNavigationStrings.followPosition,
                onPressed: onFollowPosition,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            label: '$title. ${_distanceLabel(distance)}. $_sourceLabel.',
            child: Container(
              key: const Key('return-navigation-instruction'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.96),
                borderRadius: AppRadius.xl,
                border: Border.all(
                  color: AppColors.textOnDark.withValues(alpha: 0.12),
                ),
                boxShadow: AppShadow.elevated,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: AppRadius.lg,
                    ),
                    child: Icon(
                      isApproved
                          ? Icons.alt_route_rounded
                          : _maneuverIcon(navigationStep?.modifier),
                      color: AppColors.textOnAccent,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.textOnDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _distanceLabel(distance),
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textOnDark.withValues(
                                  alpha: 0.82,
                                ),
                              ),
                            ),
                            if (remainingDuration != null)
                              Text(
                                DeliveryMapUtils.formatDuration(
                                  remainingDuration!,
                                ),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textOnDark.withValues(
                                    alpha: 0.82,
                                  ),
                                ),
                              ),
                            _GpsSourcePill(label: _sourceLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _distanceLabel(double? value) => value == null
      ? ReturnNavigationStrings.loadingRoute
      : '${ReturnNavigationStrings.remainingPrefix} '
            '${DeliveryMapUtils.formatDistance(value)}';

  String get _sourceLabel => switch (positionSource) {
    DriverPositionSource.simulation => ReturnNavigationStrings.simulationGps,
    DriverPositionSource.deviceGps => ReturnNavigationStrings.deviceGps,
    DriverPositionSource.targetFallback when isApproved =>
      ReturnNavigationStrings.routeLocked,
    _ => ReturnNavigationStrings.locatingGps,
  };

  IconData _maneuverIcon(String? modifier) => switch (modifier) {
    'left' || 'slight left' || 'sharp left' => Icons.turn_left_rounded,
    'right' || 'slight right' || 'sharp right' => Icons.turn_right_rounded,
    'uturn' => Icons.u_turn_left_rounded,
    _ => Icons.straight_rounded,
  };
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: AppRadius.full,
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.2),
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _ReturnStatusPill extends StatelessWidget {
  const _ReturnStatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.keyboard_return_rounded,
            size: 18,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              ReturnNavigationStrings.returnStatus,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsSourcePill extends StatelessWidget {
  const _GpsSourcePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.markerDriver.withValues(alpha: 0.16),
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.gps_fixed_rounded,
            size: 14,
            color: AppColors.markerDriver,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
