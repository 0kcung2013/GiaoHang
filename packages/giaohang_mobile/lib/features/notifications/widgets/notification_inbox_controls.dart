import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../notification_strings.dart';

enum NotificationInboxFilter { all, unread }

class NotificationInboxFilterBar extends StatelessWidget {
  const NotificationInboxFilterBar({
    super.key,
    required this.selected,
    required this.totalCount,
    required this.unreadCount,
    required this.onChanged,
  });

  final NotificationInboxFilter selected;
  final int totalCount;
  final int unreadCount;
  final ValueChanged<NotificationInboxFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.58),
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterOption(
              label: NotificationStrings.allFilter,
              count: totalCount,
              selected: selected == NotificationInboxFilter.all,
              onTap: () => onChanged(NotificationInboxFilter.all),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _FilterOption(
              label: NotificationStrings.unreadFilter,
              count: unreadCount,
              selected: selected == NotificationInboxFilter.unread,
              onTap: () => onChanged(NotificationInboxFilter.unread),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      child: Material(
        color: selected ? AppColors.bgCard : Colors.transparent,
        borderRadius: AppRadius.sm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.sm,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            curve: AppCurve.decelerate,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.sm,
              boxShadow: selected ? AppShadow.subtle : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentLight
                        : AppColors.bgCard.withValues(alpha: 0.72),
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: selected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
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
