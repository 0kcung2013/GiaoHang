import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../models/notification_inbox_item.dart';
import '../notification_strings.dart';
import '../utils/notification_time_formatter.dart';
import '../utils/notification_visual_style.dart';

class NotificationInboxCard extends StatelessWidget {
  const NotificationInboxCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final NotificationInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visualStyle = notificationVisualStyle(item.visualKind);
    final latest = item.latest;

    return Semantics(
      button: true,
      label: [
        if (item.isUnread) NotificationStrings.newLabel,
        latest.title,
        latest.body,
        formatNotificationTime(latest.createdAt),
      ].join('. '),
      child: Material(
        color: item.isUnread
            ? visualStyle.color.withValues(alpha: 0.045)
            : AppColors.bgCard,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          splashColor: visualStyle.color.withValues(alpha: 0.08),
          highlightColor: visualStyle.color.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
              border: Border.all(
                color: item.isUnread
                    ? visualStyle.color.withValues(alpha: 0.28)
                    : AppColors.border,
              ),
              boxShadow: item.isUnread ? AppShadow.subtle : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationIcon(visualStyle: visualStyle),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardHeader(item: item),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        latest.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _CardMeta(item: item),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.textMuted,
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

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.item});

  final NotificationInboxItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            item.latest.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: item.isUnread ? FontWeight.w800 : FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        if (item.isUnread) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: AppRadius.full,
            ),
            child: Text(
              NotificationStrings.newLabel,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textOnAccent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.item});

  final NotificationInboxItem item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Text(
          formatNotificationTime(item.lastUpdatedAt),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 0,
          ),
        ),
        if (item.updateCount > 1)
          _MetaPill(
            label: '${item.updateCount} ${NotificationStrings.updatesSuffix}',
          ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.full,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.visualStyle});

  final NotificationVisualStyle visualStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: visualStyle.color.withValues(alpha: 0.12),
        borderRadius: AppRadius.md,
      ),
      child: Icon(visualStyle.icon, color: visualStyle.color, size: 22),
    );
  }
}
