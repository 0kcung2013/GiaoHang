import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../driver_auth_strings.dart';
import '../widgets/driver_auth_field.dart';
import 'driver_register_data.dart';
import 'driver_register_validation.dart';

class DriverVehicleStep extends StatelessWidget {
  const DriverVehicleStep({super.key, required this.data, this.issue});
  final DriverRegisterData data;
  final DriverRegisterIssue? issue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        DriverAuthStrings.vehicleType,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
      ),
      const SizedBox(height: AppSpacing.sm),
      DropdownButtonFormField<String>(
        initialValue: data.vehicleType,
        isExpanded: true,
        dropdownColor: AppColors.bgCard,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        iconEnabledColor: AppColors.textMuted,
        borderRadius: AppRadius.md,
        decoration: driverInputDecoration(
          hint: DriverAuthStrings.vehicleType,
          icon: Icons.two_wheeler_rounded,
        ),
        items: DriverRegisterData.vehicleTypes
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: (v) {
          if (v != null) data.vehicleType = v;
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      DriverAuthField(
        label: DriverAuthStrings.vehicleModel,
        hint: DriverAuthStrings.vehicleModelHint,
        initialValue: data.vehicleBrandModel,
        error: issue?.forField(DriverRegisterField.model),
        onChanged: (v) => data.vehicleBrandModel = v,
      ),
      const SizedBox(height: AppSpacing.lg),
      DriverAuthField(
        label: DriverAuthStrings.vehicleColor,
        hint: DriverAuthStrings.vehicleColorHint,
        initialValue: data.vehicleColor,
        error: issue?.forField(DriverRegisterField.color),
        onChanged: (v) => data.vehicleColor = v,
      ),
      const SizedBox(height: AppSpacing.lg),
      DriverAuthField(
        label: DriverAuthStrings.licensePlate,
        hint: DriverAuthStrings.licensePlateHint,
        initialValue: data.licensePlate,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        error: issue?.forField(DriverRegisterField.plate),
        onChanged: (v) => data.licensePlate = v,
      ),
    ],
  );
}
