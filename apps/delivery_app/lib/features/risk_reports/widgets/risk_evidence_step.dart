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
    required this.messageCount,
    required this.descriptionError,
    required this.photoError,
    required this.locationError,
    required this.onDescriptionChanged,
    required this.onPickPhotos,
    required this.onCaptureLocation,
    required this.onPickMessages,
    super.key,
  });

  final TextEditingController descriptionController;
  final List<RiskPhotoInput> photos;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final bool locationRequired;
  final int messageCount;
  final String? descriptionError;
  final String? photoError;
  final String? locationError;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onPickPhotos;
  final VoidCallback onCaptureLocation;
  final VoidCallback onPickMessages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thêm thông tin', style: AppTextStyles.headingMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Mô tả ngắn gọn; bằng chứng là tùy chọn.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Mô tả sự cố', style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: descriptionController,
          onChanged: onDescriptionChanged,
          minLines: 3,
          maxLines: 5,
          maxLength: 4000,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Điều gì đã xảy ra?',
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
          icon: Icons.add_photo_alternate_outlined,
          label: 'Thêm ảnh',
          value: photos.isEmpty ? 'Tối đa 5 ảnh' : '${photos.length}/5 ảnh',
          onTap: onPickPhotos,
        ),
        if (photoError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              photoError!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        _EvidenceAction(
          icon: Icons.my_location_rounded,
          label: 'Gửi vị trí hiện tại',
          value: latitude == null || longitude == null
              ? locationRequired
                    ? RiskReportStrings.locationRequiredShort
                    : 'Không bắt buộc'
              : locationAddress ?? RiskReportStrings.locationResolving,
          onTap: onCaptureLocation,
          complete: latitude != null && longitude != null,
        ),
        if (locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              locationError!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        _EvidenceAction(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Chọn tin nhắn liên quan',
          value: messageCount == 0
              ? 'Không bắt buộc'
              : '$messageCount tin nhắn',
          onTap: onPickMessages,
          complete: messageCount > 0,
        ),
      ],
    );
  }
}

class _EvidenceAction extends StatelessWidget {
  const _EvidenceAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.complete = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
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
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: AppTextStyles.labelMedium)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: complete
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                complete
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: complete ? AppColors.success : AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
