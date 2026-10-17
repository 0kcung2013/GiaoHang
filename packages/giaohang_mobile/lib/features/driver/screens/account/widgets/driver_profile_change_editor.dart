import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../models/driver_account_view_data.dart';
import '../models/driver_profile_change_form_state.dart';
import '../utils/driver_profile_change_labels.dart';

class DriverProfileChangeEditor extends StatelessWidget {
  const DriverProfileChangeEditor({
    super.key,
    required this.profile,
    required this.state,
    required this.onValueChanged,
    required this.onPickFile,
    required this.uploadingField,
  });

  final DriverAccountViewData profile;
  final DriverProfileChangeFormState state;
  final void Function(DriverProfileChangeField, Object?) onValueChanged;
  final ValueChanged<DriverProfileChangeField> onPickFile;
  final DriverProfileChangeField? uploadingField;

  @override
  Widget build(BuildContext context) {
    if (state.selectedFields.isEmpty) return const SizedBox.shrink();
    final fields = DriverProfileChangeField.values
        .where(state.selectedFields.contains)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin mới',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final field in fields) ...[
          if (isDriverProfileFileField(field))
            _FileEditor(
              field: field,
              value: state.changes[field],
              isUploading: uploadingField == field,
              onTap: () => onPickFile(field),
            )
          else
            _ScalarEditor(
              field: field,
              currentValue: currentDriverProfileValue(profile, field),
              value: state.changes[field],
              onChanged: (value) => onValueChanged(field, value),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ScalarEditor extends StatelessWidget {
  const _ScalarEditor({
    required this.field,
    required this.currentValue,
    required this.value,
    required this.onChanged,
  });

  final DriverProfileChangeField field;
  final Object? currentValue;
  final Object? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = driverProfileChangeFieldLabel(field);
    return TextFormField(
      key: Key('${_fieldKey(field)}-change-input'),
      initialValue: value?.toString() ?? '',
      onChanged: onChanged,
      keyboardType: _keyboardType(field),
      textCapitalization: _capitalization(field),
      autofillHints: _autofillHints(field),
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Hiện tại: ${driverProfileChangeDisplayValue(currentValue)}',
        helperText: 'Chỉ được cập nhật sau khi Admin duyệt',
        helperMaxLines: 2,
        prefixIcon: Icon(driverProfileChangeFieldIcon(field), size: 20),
        filled: true,
        fillColor: AppColors.bgCard,
        border: const OutlineInputBorder(borderRadius: AppRadius.md),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.borderFocus, width: 1.5),
        ),
      ),
    );
  }

  String _fieldKey(DriverProfileChangeField field) => switch (field) {
    DriverProfileChangeField.fullName => 'full-name',
    DriverProfileChangeField.email => 'email',
    DriverProfileChangeField.phone => 'phone',
    DriverProfileChangeField.vehicleType => 'vehicle-type',
    DriverProfileChangeField.vehicleBrandModel => 'vehicle-brand-model',
    DriverProfileChangeField.vehicleColor => 'vehicle-color',
    DriverProfileChangeField.licensePlate => 'license-plate',
    DriverProfileChangeField.idCardNumber => 'id-card-number',
    DriverProfileChangeField.driverLicenseNumber => 'driver-license-number',
    _ => field.requestKey,
  };

  TextInputType _keyboardType(DriverProfileChangeField field) =>
      switch (field) {
        DriverProfileChangeField.email => TextInputType.emailAddress,
        DriverProfileChangeField.phone ||
        DriverProfileChangeField.idCardNumber ||
        DriverProfileChangeField.driverLicenseNumber => TextInputType.phone,
        _ => TextInputType.text,
      };

  TextCapitalization _capitalization(DriverProfileChangeField field) =>
      switch (field) {
        DriverProfileChangeField.email ||
        DriverProfileChangeField.phone => TextCapitalization.none,
        DriverProfileChangeField.licensePlate => TextCapitalization.characters,
        _ => TextCapitalization.words,
      };

  Iterable<String>? _autofillHints(DriverProfileChangeField field) =>
      switch (field) {
        DriverProfileChangeField.fullName => const [AutofillHints.name],
        DriverProfileChangeField.email => const [AutofillHints.email],
        DriverProfileChangeField.phone => const [AutofillHints.telephoneNumber],
        _ => null,
      };
}

class _FileEditor extends StatelessWidget {
  const _FileEditor({
    required this.field,
    required this.value,
    required this.isUploading,
    required this.onTap,
  });

  final DriverProfileChangeField field;
  final Object? value;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final uploaded = value?.toString().trim().isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.md,
        border: Border.all(
          color: uploaded ? AppColors.success : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            uploaded
                ? Icons.check_circle_rounded
                : driverProfileChangeFieldIcon(field),
            color: uploaded ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverProfileChangeFieldLabel(field),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  uploaded ? 'Đã tải ảnh mới' : 'JPG, PNG hoặc WebP',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: isUploading ? null : onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              isUploading
                  ? 'Đang tải...'
                  : uploaded
                  ? 'Đổi ảnh'
                  : 'Chọn ảnh',
            ),
          ),
        ],
      ),
    );
  }
}
