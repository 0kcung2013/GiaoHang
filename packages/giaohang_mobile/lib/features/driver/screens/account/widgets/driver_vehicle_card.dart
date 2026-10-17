import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../models/driver_account_view_data.dart';
import '../utils/driver_account_formatters.dart';
import '../utils/driver_account_strings.dart';
import 'driver_account_section_primitives.dart';

class DriverVehicleCard extends StatelessWidget {
  const DriverVehicleCard({super.key, required this.data});

  final DriverAccountViewData data;

  @override
  Widget build(BuildContext context) {
    final vehicleName = data.vehicleBrandModel.isEmpty
        ? DriverAccountStrings.vehicleFallback
        : data.vehicleBrandModel;

    return DriverAccountSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DriverAccountSectionHeading(
              icon: Icons.two_wheeler_rounded,
              title: DriverAccountStrings.vehicleTitle,
              color: AppColors.accent,
              isProtected: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              vehicleName,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: DriverAccountStrings.licensePlate,
              value: driverAccountValue(data.licensePlate),
              monospace: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: DriverAccountStrings.vehicleType,
              value: driverVehicleTypeLabel(data.vehicleType),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: DriverAccountStrings.vehicleColor,
              value: driverAccountValue(data.vehicleColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: (monospace ? AppTextStyles.mono : AppTextStyles.labelMedium)
                .copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
