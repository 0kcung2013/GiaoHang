import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

class AdminDriverProfileChangeCard extends StatelessWidget {
  const AdminDriverProfileChangeCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  final DriverProfileChangeRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final snapshot = request.currentSnapshot ?? const <String, Object?>{};
    final name = snapshot['full_name']?.toString().trim();
    final changeCount = buildDriverProfileDiff(request).length;
    final isApplying = request.status == DriverProfileChangeStatus.applying;

    return Material(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name?.isNotEmpty == true
                          ? name!
                          : 'Tài xế ${request.driverId}',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$changeCount thay đổi',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      request.reason?.trim().isNotEmpty == true
                          ? request.reason!.trim()
                          : 'Không có lý do',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: (isApplying ? AppColors.info : AppColors.warning)
                      .withValues(alpha: 0.1),
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  isApplying ? 'Đang áp dụng' : 'Chờ duyệt',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isApplying ? AppColors.info : AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
