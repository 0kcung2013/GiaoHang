import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../models/driver_account_view_data.dart';
import '../utils/driver_account_formatters.dart';
import '../utils/driver_account_strings.dart';
import 'driver_account_section_primitives.dart';

class DriverVerificationCard extends StatelessWidget {
  const DriverVerificationCard({super.key, required this.data});

  final DriverAccountViewData data;

  @override
  Widget build(BuildContext context) {
    return DriverAccountSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DriverAccountSectionHeading(
              icon: Icons.shield_outlined,
              title: DriverAccountStrings.verificationTitle,
              color: AppColors.info,
              isProtected: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              DriverAccountStrings.verificationMessage,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _VerificationRow(
              icon: Icons.badge_outlined,
              label: DriverAccountStrings.identityCard,
              completed: data.hasIdentityCard,
              value: driverMaskedDocument(data.idCardNumber),
            ),
            const _SectionDivider(),
            _VerificationRow(
              icon: Icons.credit_card_rounded,
              label: DriverAccountStrings.driverLicense,
              completed: data.hasDriverLicense,
              value: driverMaskedDocument(data.driverLicenseNumber),
            ),
            const _SectionDivider(),
            _VerificationRow(
              icon: Icons.photo_camera_outlined,
              label: DriverAccountStrings.vehiclePhoto,
              completed: data.hasVehiclePhoto,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.icon,
    required this.label,
    required this.completed,
    this.value,
  });

  final IconData icon;
  final String label;
  final bool completed;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.success : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 21),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value!,
                    style: AppTextStyles.mono.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            completed ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              completed
                  ? DriverAccountStrings.completed
                  : DriverAccountStrings.missing,
              textAlign: TextAlign.end,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.textMuted,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 33, color: AppColors.border);
  }
}
