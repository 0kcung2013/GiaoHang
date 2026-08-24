import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/driver_profile_change_labels.dart';

class DriverProfileChangeFieldSelector extends StatelessWidget {
  const DriverProfileChangeFieldSelector({
    super.key,
    required this.selectedFields,
    required this.onToggle,
  });

  final Set<DriverProfileChangeField> selectedFields;
  final ValueChanged<DriverProfileChangeField> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldGroup(
          title: 'Thông tin cá nhân',
          fields: const [
            DriverProfileChangeField.fullName,
            DriverProfileChangeField.email,
            DriverProfileChangeField.phone,
            DriverProfileChangeField.avatar,
          ],
          selectedFields: selectedFields,
          onToggle: onToggle,
        ),
        const SizedBox(height: AppSpacing.lg),
        _FieldGroup(
          title: 'Phương tiện',
          fields: const [
            DriverProfileChangeField.vehicleType,
            DriverProfileChangeField.vehicleBrandModel,
            DriverProfileChangeField.vehicleColor,
            DriverProfileChangeField.licensePlate,
            DriverProfileChangeField.vehiclePhoto,
          ],
          selectedFields: selectedFields,
          onToggle: onToggle,
        ),
        const SizedBox(height: AppSpacing.lg),
        _FieldGroup(
          title: 'Hồ sơ xác minh',
          fields: const [
            DriverProfileChangeField.idCardNumber,
            DriverProfileChangeField.idCardFront,
            DriverProfileChangeField.idCardBack,
            DriverProfileChangeField.driverLicenseNumber,
            DriverProfileChangeField.driverLicense,
          ],
          selectedFields: selectedFields,
          onToggle: onToggle,
        ),
      ],
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({
    required this.title,
    required this.fields,
    required this.selectedFields,
    required this.onToggle,
  });

  final String title;
  final List<DriverProfileChangeField> fields;
  final Set<DriverProfileChangeField> selectedFields;
  final ValueChanged<DriverProfileChangeField> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                _SelectableFieldRow(
                  field: fields[index],
                  selected: selectedFields.contains(fields[index]),
                  onTap: () => onToggle(fields[index]),
                ),
                if (index < fields.length - 1)
                  const Divider(height: 1, indent: 52, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectableFieldRow extends StatelessWidget {
  const _SelectableFieldRow({
    required this.field,
    required this.selected,
    required this.onTap,
  });

  final DriverProfileChangeField field;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: selected,
      child: Material(
        color: selected
            ? AppColors.accentLight.withValues(alpha: 0.65)
            : AppColors.bgCard,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    driverProfileChangeFieldIcon(field),
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    size: 21,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      driverProfileChangeFieldLabel(field),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AnimatedContainer(
                    duration: AppDuration.fast,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent : AppColors.bgCard,
                      borderRadius: AppRadius.xs,
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: AppColors.textOnAccent,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
