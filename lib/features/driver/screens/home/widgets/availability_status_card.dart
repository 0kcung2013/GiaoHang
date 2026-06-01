import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/driver_model.dart';
import 'driver_state_widgets.dart';

/// Card showing whether the driver is available and quick counts.
class AvailabilityStatusCard extends StatelessWidget {
  final DriverModel driver;
  final int availableCount;
  final int activeCount;

  const AvailabilityStatusCard({
    super.key,
    required this.driver,
    required this.availableCount,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = driver.isAvailable;
    final color = isAvailable ? AppColors.success : AppColors.error;

    return DriverSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.lg,
              ),
              child: Icon(
                isAvailable
                    ? Icons.radio_button_checked_rounded
                    : Icons.pause_circle_filled_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAvailable ? 'Đang sẵn sàng nhận đơn' : 'Đang tạm nghỉ',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isAvailable
                        ? 'Có $availableCount đơn mới và $activeCount đơn đang xử lý.'
                        : 'Bật trạng thái sẵn sàng trong hồ sơ tài xế để nhận đơn mới.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
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
}
