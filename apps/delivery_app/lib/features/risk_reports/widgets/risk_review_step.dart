import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/risk_report_options.dart';
import '../utils/risk_report_strings.dart';

class RiskReviewStep extends StatelessWidget {
  const RiskReviewStep({
    required this.trackingCode,
    required this.option,
    required this.description,
    required this.photoCount,
    required this.hasLocation,
    required this.locationAddress,
    required this.messageCount,
    super.key,
  });

  final String trackingCode;
  final RiskReportOption? option;
  final String description;
  final int photoCount;
  final bool hasLocation;
  final String? locationAddress;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Xác nhận báo cáo', style: AppTextStyles.headingMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'CSKH sẽ kiểm tra và phản hồi trong quá trình xử lý.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(label: 'Mã đơn', value: trackingCode),
              const Divider(height: AppSpacing.xl2, color: AppColors.border),
              _SummaryRow(label: 'Vấn đề', value: option?.label ?? ''),
              const SizedBox(height: AppSpacing.md),
              Text('Mô tả', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(description, style: AppTextStyles.bodyMedium),
              if (hasLocation) ...[
                const Divider(height: AppSpacing.xl2, color: AppColors.border),
                _SummaryRow(
                  label: RiskReportStrings.locationSummaryLabel,
                  value: locationAddress ?? RiskReportStrings.locationResolving,
                ),
              ],
              const Divider(height: AppSpacing.xl2, color: AppColors.border),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _EvidenceBadge(
                    icon: Icons.photo_outlined,
                    label: '$photoCount ảnh',
                    active: photoCount > 0,
                  ),
                  _EvidenceBadge(
                    icon: Icons.my_location_rounded,
                    label: hasLocation ? 'Có vị trí' : 'Không vị trí',
                    active: hasLocation,
                  ),
                  _EvidenceBadge(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '$messageCount tin nhắn',
                    active: messageCount > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.info,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Báo cáo không tự động kết luận vi phạm hoặc dừng đơn hàng.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTextStyles.labelMedium)),
      ],
    );
  }
}

class _EvidenceBadge extends StatelessWidget {
  const _EvidenceBadge({
    required this.icon,
    required this.label,
    required this.active,
  });
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.accentLight : AppColors.bgCard,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: active ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
