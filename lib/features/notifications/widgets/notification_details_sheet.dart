import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/models/notification_model.dart';
import '../models/notification_inbox_item.dart';
import '../notification_strings.dart';
import '../utils/notification_time_formatter.dart';
import '../utils/notification_visual_style.dart';

Future<void> showNotificationDetailsSheet({
  required BuildContext context,
  required NotificationInboxItem item,
  VoidCallback? onViewOrder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.52),
    builder: (sheetContext) => _NotificationDetailsSheet(
      item: item,
      onViewOrder: onViewOrder == null
          ? null
          : () {
              Navigator.of(sheetContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onViewOrder();
              });
            },
    ),
  );
}

class _NotificationDetailsSheet extends StatelessWidget {
  const _NotificationDetailsSheet({
    required this.item,
    required this.onViewOrder,
  });

  final NotificationInboxItem item;
  final VoidCallback? onViewOrder;

  @override
  Widget build(BuildContext context) {
    final visualStyle = notificationVisualStyle(item.visualKind);
    final previousEvents = item.notifications.skip(1).toList();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.xl2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(onClose: () => Navigator.of(context).pop()),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xl2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LatestUpdate(item: item, visualStyle: visualStyle),
                      if (previousEvents.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl2),
                        Text(
                          NotificationStrings.previousUpdates,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (
                          var index = 0;
                          index < previousEvents.length;
                          index++
                        )
                          _TimelineEvent(
                            notification: previousEvents[index],
                            isLast: index == previousEvents.length - 1,
                            color: visualStyle.color,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onViewOrder != null)
                _ViewOrderAction(onPressed: onViewOrder!),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.full,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: NotificationStrings.close,
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestUpdate extends StatelessWidget {
  const _LatestUpdate({required this.item, required this.visualStyle});

  final NotificationInboxItem item;
  final NotificationVisualStyle visualStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: visualStyle.color.withValues(alpha: 0.12),
              borderRadius: AppRadius.lg,
            ),
            child: Icon(visualStyle.icon, color: visualStyle.color, size: 26),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.latest.title,
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatNotificationTime(item.latest.createdAt),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  item.latest.body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({
    required this.notification,
    required this.isLast,
    required this.color,
  });

  final NotificationModel notification;
  final bool isLast;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSpacing.xl,
            child: Column(
              children: [
                Container(
                  width: AppSpacing.sm,
                  height: AppSpacing.sm,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notification.body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatNotificationTime(notification.createdAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewOrderAction extends StatelessWidget {
  const _ViewOrderAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textOnAccent,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
          ),
          icon: const Icon(Icons.receipt_long_rounded, size: 20),
          label: Text(
            NotificationStrings.viewOrder,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textOnAccent,
            ),
          ),
        ),
      ),
    );
  }
}
