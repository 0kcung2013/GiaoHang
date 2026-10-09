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
    final completedCount = [
      data.hasIdentityCard,
      data.hasDriverLicense,
      data.hasVehiclePhoto,
    ].where((completed) => completed).length;

    return DriverAccountSectionCard(
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.xl,
        ),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        leading: const Icon(Icons.shield_outlined, color: AppColors.info),
        title: Text(
          DriverAccountStrings.verificationTitle,
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '$completedCount/3 ${DriverAccountStrings.verificationSummary}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        children: [
          const Divider(height: 1, color: AppColors.border),
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
    final color = completed ? AppColors.success : AppColors.textSecondary;
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
