import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

/// Một hồ sơ: vấn đề, người gửi/mã đơn, trạng thái và việc cần chú ý.
class SupportCaseListItem extends StatelessWidget {
  const SupportCaseListItem({
    required this.title,
    required this.identity,
    required this.assignment,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.onTap,
    this.preview,
    this.alerts = const [],
    super.key,
  });
  final String title;
  final String identity;
  final String assignment;
  final String time;
  final String status;
  final Color statusColor;
  final IconData icon;
  final VoidCallback onTap;
  final String? preview;
  final List<Widget> alerts;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.bgLight,
        focusColor: AppColors.accentLight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSpacing.xl5,
                height: AppSpacing.xl5,
                decoration: const BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(icon, color: AppColors.textSecondary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      identity,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (preview?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        preview!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          status,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: statusColor,
                          ),
                        ),
                        ...alerts,
                        Text(
                          assignment,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          time,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
