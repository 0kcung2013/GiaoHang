import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class RiskReportLoading extends StatelessWidget {
  const RiskReportLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => Container(
        height: 170,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonLine(width: 150, height: 24),
            SizedBox(height: AppSpacing.lg),
            _SkeletonLine(width: 260, height: 18),
            SizedBox(height: AppSpacing.sm),
            _SkeletonLine(width: 190, height: 14),
            Spacer(),
            _SkeletonLine(width: double.infinity, height: 42),
          ],
        ),
      ),
    );
  }
}

class RiskReportEmpty extends StatelessWidget {
  const RiskReportEmpty({
    required this.title,
    required this.subtitle,
    this.onRetry,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.xl,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.headingSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.border,
        borderRadius: AppRadius.sm,
      ),
    );
  }
}
