import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../models/driver_account_view_data.dart';
import '../models/driver_profile_change_form_state.dart';
import '../utils/driver_account_formatters.dart';
import '../utils/driver_profile_change_labels.dart';

class DriverProfileChangeReview extends StatelessWidget {
  const DriverProfileChangeReview({
    super.key,
    required this.profile,
    required this.changes,
    required this.reason,
  });

  final DriverAccountViewData profile;
  final Map<DriverProfileChangeField, Object?> changes;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.09),
            borderRadius: AppRadius.md,
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppColors.warning,
                size: 21,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Admin sẽ duyệt toàn bộ yêu cầu. Không có thay đổi nào được áp dụng trước khi được duyệt.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '${changes.length} thông tin cần thay đổi',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final entry in changes.entries) ...[
          _ChangeReviewRow(
            field: entry.key,
            currentValue: currentDriverProfileValue(profile, entry.key),
            requestedValue: entry.value,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'Lý do thay đổi',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            reason,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangeReviewRow extends StatelessWidget {
  const _ChangeReviewRow({
    required this.field,
    required this.currentValue,
    required this.requestedValue,
  });

  final DriverProfileChangeField field;
  final Object? currentValue;
  final Object? requestedValue;

  @override
  Widget build(BuildContext context) {
    final isFile = isDriverProfileFileField(field);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                driverProfileChangeFieldIcon(field),
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  driverProfileChangeFieldLabel(field),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ValueLine(
            label: 'Hiện tại',
            value: isFile
                ? currentValue == null
                      ? 'Chưa cập nhật'
                      : 'Đã có ảnh'
                : _display(field, currentValue),
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ValueLine(
            label: 'Yêu cầu mới',
            value: isFile
                ? 'Ảnh mới đã tải lên'
                : _display(field, requestedValue),
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  String _display(DriverProfileChangeField field, Object? value) {
    if (field == DriverProfileChangeField.idCardNumber ||
        field == DriverProfileChangeField.driverLicenseNumber) {
      return driverMaskedDocument(value?.toString());
    }
    return driverProfileChangeDisplayValue(value);
  }
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
