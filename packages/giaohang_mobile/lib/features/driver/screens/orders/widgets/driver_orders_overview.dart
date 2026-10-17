import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../utils/driver_orders_strings.dart';

class DriverOrdersOverview extends StatelessWidget {
  const DriverOrdersOverview({
    super.key,
    required this.isAvailable,
    required this.hasActiveOrder,
    required this.availableCount,
    required this.activeCount,
    required this.completedCount,
  });

  final bool isAvailable;
  final bool hasActiveOrder;
  final int availableCount;
  final int activeCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Semantics(
      container: true,
      label: '${DriverOrdersStrings.overviewEyebrow}. ${status.title}',
      child: Container(
        key: const ValueKey('driver_orders_overview_card'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl2,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
          boxShadow: AppShadow.card,
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -42,
              top: -58,
              child: _DecorativeOrb(size: 156, color: AppColors.accent),
            ),
            const Positioned(
              left: -34,
              bottom: -62,
              child: _DecorativeOrb(size: 126, color: AppColors.accent),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: AppRadius.lg,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: AppColors.accent,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DriverOrdersStrings.overviewEyebrow,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              status.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.headingMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatusPill(
                        label: status.label,
                        icon: status.icon,
                        color: status.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    status.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgWarm,
                      borderRadius: AppRadius.lg,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        _Metric(
                          value: availableCount,
                          label: DriverOrdersStrings.availableMetric,
                        ),
                        const _MetricDivider(),
                        _Metric(
                          value: activeCount,
                          label: DriverOrdersStrings.activeMetric,
                        ),
                        const _MetricDivider(),
                        _Metric(
                          value: completedCount,
                          label: DriverOrdersStrings.completedMetric,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String label, String title, String message, IconData icon, Color color})
  get _status {
    if (hasActiveOrder) {
      return (
        label: DriverOrdersStrings.activeStatus,
        title: DriverOrdersStrings.activeTitle,
        message: DriverOrdersStrings.activeMessage,
        icon: Icons.navigation_rounded,
        color: AppColors.accent,
      );
    }
    if (isAvailable) {
      return (
        label: DriverOrdersStrings.availableStatus,
        title: DriverOrdersStrings.readyTitle,
        message: DriverOrdersStrings.readyMessage,
        icon: Icons.radio_button_checked_rounded,
        color: AppColors.success,
      );
    }
    return (
      label: DriverOrdersStrings.pausedStatus,
      title: DriverOrdersStrings.pausedTitle,
      message: DriverOrdersStrings.pausedMessage,
      icon: Icons.pause_circle_filled_rounded,
      color: AppColors.textMuted,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.accent.withValues(alpha: 0.16),
    );
  }
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
