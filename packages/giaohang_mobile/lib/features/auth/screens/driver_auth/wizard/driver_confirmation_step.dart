import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../driver_auth_strings.dart';
import '../widgets/driver_auth_feedback.dart';
import 'driver_register_data.dart';

class DriverConfirmationStep extends StatelessWidget {
  const DriverConfirmationStep({super.key, required this.data});
  final DriverRegisterData data;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SummarySection(
        title: DriverAuthStrings.personalSection,
        icon: Icons.person_outline_rounded,
        rows: [
          (DriverAuthStrings.fullName, data.fullName),
          (DriverAuthStrings.email, data.email),
          (DriverAuthStrings.phone, data.phone),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      _SummarySection(
        title: DriverAuthStrings.vehicleSection,
        icon: Icons.two_wheeler_rounded,
        rows: [
          (DriverAuthStrings.vehicleType, data.vehicleType),
          (DriverAuthStrings.vehicleModel, data.vehicleBrandModel),
          (DriverAuthStrings.vehicleColor, data.vehicleColor),
          (DriverAuthStrings.licensePlate, data.licensePlate),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      _SummarySection(
        title: DriverAuthStrings.documentsSection,
        icon: Icons.badge_rounded,
        rows: [
          (DriverAuthStrings.idNumber, data.idCardNumber),
          (DriverAuthStrings.licenseNumber, data.driverLicenseNumber),
        ],
        photos: [
          if (data.avatarFile != null) DriverAuthStrings.avatar,
          if (data.idCardFrontFile != null) DriverAuthStrings.idFront,
          if (data.idCardBackFile != null) DriverAuthStrings.idBack,
          if (data.driverLicenseFile != null) DriverAuthStrings.licensePhoto,
          if (data.vehiclePhotoFile != null) DriverAuthStrings.vehiclePhoto,
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      const DriverAuthNotice(message: DriverAuthStrings.reviewNotice),
    ],
  );
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.icon,
    required this.rows,
    this.photos = const [],
  });
  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  final List<String> photos;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  row.$1,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  row.$2.isEmpty ? '—' : row.$2,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        for (final photo in photos)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    photo,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
