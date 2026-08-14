import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';

class SupportTicketLoading extends StatelessWidget {
  const SupportTicketLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Đang tải yêu cầu hỗ trợ',
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            height: 148,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Skeleton(width: index == 1 ? 220 : 280, height: 18),
                const SizedBox(height: AppSpacing.md),
                const _Skeleton(width: double.infinity, height: 12),
                const SizedBox(height: AppSpacing.sm),
                const _Skeleton(width: 190, height: 12),
                const Spacer(),
                const _Skeleton(width: 140, height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SupportTicketEmpty extends StatelessWidget {
  const SupportTicketEmpty({
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.xl,
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  size: 34,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.md,
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(SupportTicketStrings.retry),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.7),
        borderRadius: AppRadius.full,
      ),
    );
  }
}
