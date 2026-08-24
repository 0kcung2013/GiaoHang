import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../data/admin_driver_media_resolver.dart';
import '../utils/admin_driver_profile_change_labels.dart';
import 'admin_driver_media_preview.dart';

class AdminDriverProfileChangeDiff extends StatelessWidget {
  const AdminDriverProfileChangeDiff({
    super.key,
    required this.request,
    required this.mediaResolver,
  });

  final DriverProfileChangeRequest request;
  final AdminDriverMediaResolver mediaResolver;

  @override
  Widget build(BuildContext context) {
    final diffs = buildDriverProfileDiff(request);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${diffs.length} thay đổi trong yêu cầu',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final diff in diffs) ...[
          _DiffCard(diff: diff, mediaResolver: mediaResolver),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _DiffCard extends StatelessWidget {
  const _DiffCard({required this.diff, required this.mediaResolver});

  final DriverProfileFieldDiff diff;
  final AdminDriverMediaResolver mediaResolver;

  @override
  Widget build(BuildContext context) {
    final isMedia = isAdminDriverProfileMediaField(diff.field);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  adminDriverProfileFieldIcon(diff.field),
                  color: AppColors.accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  adminDriverProfileFieldLabel(diff.field),
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isMedia)
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                AdminDriverMediaPreview(
                  label: 'Hiện tại',
                  storedValue: diff.currentValue?.toString(),
                  resolver: mediaResolver,
                ),
                AdminDriverMediaPreview(
                  label: 'Yêu cầu mới',
                  storedValue: diff.requestedValue?.toString(),
                  resolver: mediaResolver,
                ),
              ],
            )
          else
            _ValueComparison(
              currentValue: adminDriverProfileDisplayValue(
                diff.field,
                diff.currentValue,
              ),
              requestedValue: adminDriverProfileDisplayValue(
                diff.field,
                diff.requestedValue,
              ),
            ),
        ],
      ),
    );
  }
}

class _ValueComparison extends StatelessWidget {
  const _ValueComparison({
    required this.currentValue,
    required this.requestedValue,
  });

  final String currentValue;
  final String requestedValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ValueBlock(
            label: 'Hiện tại',
            value: currentValue,
            color: AppColors.textSecondary,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
            0,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ),
        Expanded(
          child: _ValueBlock(
            label: 'Yêu cầu mới',
            value: requestedValue,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTextStyles.labelMedium.copyWith(color: color)),
      ],
    );
  }
}
