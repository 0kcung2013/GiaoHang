import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../notification_strings.dart';

class NotificationInboxLoading extends StatelessWidget {
  const NotificationInboxLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) => const _NotificationSkeleton(),
    );
  }
}

class NotificationInboxError extends StatelessWidget {
  const NotificationInboxError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.error,
      title: NotificationStrings.loadErrorTitle,
      message: NotificationStrings.loadErrorMessage,
      action: SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnDark,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: Text(
            NotificationStrings.retry,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationInboxEmpty extends StatelessWidget {
  const NotificationInboxEmpty({super.key, required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: unreadOnly
          ? Icons.done_all_rounded
          : Icons.notifications_none_rounded,
      iconColor: unreadOnly ? AppColors.success : AppColors.textMuted,
      title: unreadOnly
          ? NotificationStrings.unreadEmptyTitle
          : NotificationStrings.emptyTitle,
      message: unreadOnly
          ? NotificationStrings.unreadEmptyMessage
          : NotificationStrings.emptyMessage,
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.xl,
                ),
                child: Icon(icon, size: 30, color: iconColor),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBlock(width: 44, height: 44, radius: AppSpacing.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBlock(width: 160, height: 14),
                const SizedBox(height: AppSpacing.md),
                _SkeletonBlock(
                  width: MediaQuery.sizeOf(context).width,
                  height: AppSpacing.md,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _SkeletonBlock(width: 96, height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = AppSpacing.xs,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
