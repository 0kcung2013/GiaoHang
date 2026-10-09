import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../driver_cancellation_strings.dart';
import '../models/driver_cancellation_policy.dart';
import 'driver_deadline_countdown.dart';

class DriverAcceptanceLockCard extends StatelessWidget {
  const DriverAcceptanceLockCard({
    super.key,
    required this.lockedUntil,
    required this.onExpired,
    this.now = DateTime.now,
  });

  final DateTime lockedUntil;
  final VoidCallback onExpired;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.xl2),
    decoration: BoxDecoration(
      color: AppColors.bgDarkCard,
      borderRadius: AppRadius.xl,
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
    ),
    child: Column(
      children: [
        const Icon(Icons.lock_clock_rounded, color: AppColors.warning),
        const SizedBox(height: AppSpacing.md),
        Text(
          DriverCancellationStrings.lockTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textOnDark,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        DriverDeadlineCountdown(
          deadline: lockedUntil,
          totalDuration: DriverCancellationPolicy.personalLock,
          onExpired: onExpired,
          now: now,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          DriverCancellationStrings.lockDescription,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textOnDark),
        ),
      ],
    ),
  );
}
