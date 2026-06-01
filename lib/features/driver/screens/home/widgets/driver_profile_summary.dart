import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/driver_model.dart';
import '../utils/driver_home_formatters.dart';

/// Hero banner at the top showing driver name/vehicle info and rating chips.
class DriverProfileSummary extends StatelessWidget {
  final DriverModel driver;

  const DriverProfileSummary({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final vehicle = joinNonEmpty([driver.vehicleType, driver.licensePlate]);
    final rating = driver.rating == null
        ? 'Chưa có đánh giá'
        : '${driver.rating!.toStringAsFixed(1)} điểm';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.18),
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.info.withValues(alpha: 0.28)),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.textOnDark,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bảng điều khiển tài xế',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  vehicle.isEmpty ? 'Hồ sơ tài xế đã kết nối' : vehicle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _HeaderChip(label: rating, icon: Icons.star_rounded),
                    _HeaderChip(
                      label: '${driver.totalDeliveries} chuyến đã giao',
                      icon: Icons.check_circle_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeaderChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textOnDark, size: 14),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textOnDark,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
