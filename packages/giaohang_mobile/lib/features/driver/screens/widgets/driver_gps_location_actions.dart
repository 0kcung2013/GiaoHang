import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/location/driver_location_producer_policy.dart';

class DriverGpsLocationActions extends StatelessWidget {
  const DriverGpsLocationActions({
    super.key,
    required this.applyingMode,
    required this.canUseDemo,
    required this.onUseDemoCurrentPosition,
    required this.onUseDemoHcm,
  });

  final DriverLocationMode? applyingMode;
  final bool canUseDemo;
  final VoidCallback onUseDemoCurrentPosition;
  final VoidCallback onUseDemoHcm;

  @override
  Widget build(BuildContext context) {
    final isApplying = applyingMode != null;
    final demoLabel = applyingMode == DriverLocationMode.demoHcm
        ? 'Đang áp dụng demo...'
        : 'Dùng vị trí demo TP.HCM';
    final currentDemoLabel =
        applyingMode == DriverLocationMode.demoCurrentPosition
        ? 'Đang bật mô phỏng...'
        : 'Mô phỏng từ vị trí hiện tại';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            key: const ValueKey('use-demo-current-position'),
            onPressed: isApplying ? null : onUseDemoCurrentPosition,
            icon: const Icon(Icons.route_rounded),
            label: Text(currentDemoLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              disabledForegroundColor: AppColors.textMuted,
              side: BorderSide(
                color: isApplying
                    ? AppColors.border
                    : AppColors.accent.withValues(alpha: 0.45),
              ),
              textStyle: AppTextStyles.labelLarge,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('use-demo-hcm'),
            onPressed: isApplying || !canUseDemo ? null : onUseDemoHcm,
            icon: const Icon(Icons.location_city_rounded),
            label: Text(demoLabel),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textOnAccent,
              disabledBackgroundColor: AppColors.accentLight,
              disabledForegroundColor: AppColors.textMuted,
              textStyle: AppTextStyles.labelLarge,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
            ),
          ),
        ),
      ],
    );
  }
}
