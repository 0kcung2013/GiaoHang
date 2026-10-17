import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../data/risk_report_repository.dart';
import '../utils/risk_report_strings.dart';

class RiskEvidenceStep extends StatelessWidget {
  const RiskEvidenceStep({
    required this.descriptionController,
    required this.photos,
    required this.latitude,
    required this.longitude,
    required this.locationAddress,
    required this.locationRequired,
    required this.descriptionError,
    required this.photoError,
    required this.locationError,
    required this.onDescriptionChanged,
    required this.onPickPhotos,
    required this.onCaptureLocation,
    this.callEvidenceRequired = false,
    this.photoRequired = false,
    this.compact = false,
    this.showLocation = true,
    this.onRemovePhoto,
    this.descriptionHint = 'Điều gì đã xảy ra?',
    this.descriptionLimit = 4000,
    super.key,
  });

  final TextEditingController descriptionController;
  final List<RiskPhotoInput> photos;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final bool locationRequired;
  final String? descriptionError;
  final String? photoError;
  final String? locationError;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onPickPhotos;
  final VoidCallback onCaptureLocation;
  final bool callEvidenceRequired;
  final bool photoRequired;
  final bool compact;
  final bool showLocation;
  final ValueChanged<int>? onRemovePhoto;
  final String descriptionHint;
  final int descriptionLimit;

  @override
  Widget build(BuildContext context) {
    final hasLocation = latitude != null && longitude != null;
    final locationLocked = locationRequired && hasLocation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text('Thêm thông tin', style: AppTextStyles.headingMedium),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('Mô tả', style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: descriptionController,
          onChanged: onDescriptionChanged,
          minLines: 3,
          maxLines: 5,
          maxLength: descriptionLimit,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: descriptionHint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            errorText: descriptionError,
            filled: true,
            fillColor: AppColors.bgLight,
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.md,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.md,
              borderSide: BorderSide(color: AppColors.borderFocus, width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.md,
              borderSide: BorderSide(color: AppColors.error),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _EvidenceAction(
          label: callEvidenceRequired ? 'Thêm ảnh cuộc gọi' : 'Thêm ảnh',
          value: photos.isEmpty
              ? callEvidenceRequired || photoRequired
                    ? 'Bắt buộc · tối đa 5 ảnh'
                    : 'Tùy chọn · tối đa 5 ảnh'
              : '${photos.length}/5 ảnh',
          onTap: onPickPhotos,
        ),
        if (callEvidenceRequired)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              RiskReportStrings.callEvidenceHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (photoError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              photoError!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        if (photos.isNotEmpty && onRemovePhoto != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: List.generate(
                photos.length,
                (index) => InputChip(
                  label: Text('Ảnh ${index + 1}'),
                  onDeleted: () => onRemovePhoto!(index),
                  deleteButtonTooltipMessage: 'Bỏ ảnh ${index + 1}',
                  backgroundColor: AppColors.bgLight,
                  labelStyle: AppTextStyles.labelMedium,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        if (showLocation) ...[
          const SizedBox(height: AppSpacing.sm),
          _EvidenceAction(
            label: 'Gửi vị trí hiện tại',
            value: !hasLocation
                ? locationRequired
                      ? RiskReportStrings.locationRequiredShort
                      : 'Không bắt buộc'
                : locationAddress ?? RiskReportStrings.locationResolving,
            onTap: locationLocked ? null : onCaptureLocation,
            complete: hasLocation,
            muted: locationLocked,
            semanticsKey: const ValueKey('risk-required-location-action'),
            semanticsLabel: locationLocked
                ? 'Vị trí hiện tại bắt buộc, đã tự động đính kèm'
                : null,
          ),
          if (locationError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                locationError!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ],
    );
  }
}

class _EvidenceAction extends StatelessWidget {
  const _EvidenceAction({
    required this.label,
    required this.value,
    required this.onTap,
    this.complete = false,
    this.muted = false,
    this.semanticsKey,
    this.semanticsLabel,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool complete;
  final bool muted;
  final Key? semanticsKey;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticsKey,
      button: !muted,
      enabled: !muted,
      label: semanticsLabel,
      child: Material(
        color: muted ? AppColors.bgLight : AppColors.bgCard,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (complete) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        RiskReportStrings.attached,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
