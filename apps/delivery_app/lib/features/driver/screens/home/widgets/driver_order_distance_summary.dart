import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../driver_home_strings.dart';
import '../utils/driver_order_distance.dart';

/// Hai quãng đường quan trọng nhất để tài xế quyết định nhận đơn.
class DriverOrderDistanceSummary extends StatelessWidget {
  const DriverOrderDistanceSummary({
    super.key,
    required this.pickupDistanceMeters,
    required this.totalDistanceMeters,
  });

  final double? pickupDistanceMeters;
  final double? totalDistanceMeters;

  @override
  Widget build(BuildContext context) {
    final pickupText = distanceKilometersText(pickupDistanceMeters);
    final totalText = distanceKilometersText(totalDistanceMeters);

    return Semantics(
      container: true,
      label: DriverHomeStrings.distanceSummarySemantic(
        pickupText: pickupText,
        totalText: totalText,
      ),
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _DistanceMetric(
                  icon: Icons.storefront_rounded,
                  label: DriverHomeStrings.pickupDistanceLabel,
                  value: pickupText,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DistanceMetric(
                  icon: Icons.route_rounded,
                  label: DriverHomeStrings.totalDistanceLabel,
                  value: totalText,
                  color: AppColors.accent,
                  emphasized: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistanceMetric extends StatelessWidget {
  const _DistanceMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.11 : 0.07),
        borderRadius: AppRadius.md,
        border: Border.all(
          color: color.withValues(alpha: emphasized ? 0.38 : 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            style: AppTextStyles.headingLarge.copyWith(
              color: emphasized ? AppColors.accent : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}
