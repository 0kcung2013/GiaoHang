import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/providers/customer_providers.dart';
import '../models/notification_inbox_item.dart';
import '../notification_strings.dart';
import '../widgets/notification_details_sheet.dart';
import '../widgets/notification_inbox_card.dart';
import '../widgets/notification_inbox_controls.dart';
import '../widgets/notification_inbox_states.dart';

/// Hộp thư thông báo dùng chung, được gom theo hành trình của từng đơn hàng.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, required this.audience});

  final NotificationAudience audience;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationInboxFilter _filter = NotificationInboxFilter.all;
  bool _isMarkingAllRead = false;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const _SignedOutNotificationsView();

    ref.watch(notificationsRealtimeProvider(user.id));
    final notificationsAsync = ref.watch(notificationsProvider(user.id));
    final hasUnread =
        notificationsAsync.valueOrNull?.any((item) => !item.isRead) ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          NotificationStrings.screenTitle,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _isMarkingAllRead
                  ? null
                  : () => _markAllAsRead(user.id),
              child: AnimatedOpacity(
                duration: AppDuration.fast,
                opacity: _isMarkingAllRead ? 0.5 : 1,
                child: Text(
                  NotificationStrings.markAllRead,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: notificationsAsync.when(
        loading: () => const NotificationInboxLoading(),
        error: (_, _) => NotificationInboxError(
          onRetry: () => ref.invalidate(notificationsProvider(user.id)),
        ),
        data: (notifications) {
          final inbox = buildNotificationInbox(
            notifications,
            audience: widget.audience,
          );
          return _NotificationInboxBody(
            inbox: inbox,
            filter: _filter,
            onFilterChanged: (filter) => setState(() => _filter = filter),
            onRefresh: () => _refresh(user.id),
            onItemTap: (item) {
              unawaited(_markItemAsRead(item, user.id));
              final canOpenOrder =
                  item.orderId != null &&
                  (widget.audience == NotificationAudience.customer ||
                      item.isActionRequired);
              showNotificationDetailsSheet(
                context: context,
                item: item,
                onViewOrder: canOpenOrder ? _openOrders : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _refresh(String userId) async {
    ref.invalidate(notificationsProvider(userId));
    ref.invalidate(unreadNotificationCountProvider(userId));
    await ref.read(notificationsProvider(userId).future);
  }

  Future<void> _markItemAsRead(
    NotificationInboxItem item,
    String userId,
  ) async {
    if (item.unreadIds.isEmpty) return;
    try {
      await ref
          .read(notificationServiceProvider)
          .markNotificationsAsRead(item.unreadIds, userId);
      ref.invalidate(notificationsProvider(userId));
      ref.invalidate(unreadNotificationCountProvider(userId));
    } catch (_) {
      // Nội dung vẫn mở được; realtime hoặc lần refresh sau sẽ đồng bộ lại.
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    setState(() => _isMarkingAllRead = true);
    try {
      await ref.read(notificationServiceProvider).markAllAsRead(userId);
      ref.invalidate(notificationsProvider(userId));
      ref.invalidate(unreadNotificationCountProvider(userId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          content: Text(
            NotificationStrings.markReadError,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  void _openOrders() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();

    switch (widget.audience) {
      case NotificationAudience.customer:
        router.go('/customer-home?tab=orders');
        return;
      case NotificationAudience.driver:
        router.go('/driver-home?tab=home');
        return;
    }
  }
}

class _NotificationInboxBody extends StatelessWidget {
  const _NotificationInboxBody({
    required this.inbox,
    required this.filter,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onItemTap,
  });

  final List<NotificationInboxItem> inbox;
  final NotificationInboxFilter filter;
  final ValueChanged<NotificationInboxFilter> onFilterChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<NotificationInboxItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final unreadCount = inbox.where((item) => item.isUnread).length;
    final visibleItems = filter == NotificationInboxFilter.unread
        ? inbox.where((item) => item.isUnread).toList()
        : inbox;
    final actionItems = visibleItems
        .where((item) => item.isActionRequired)
        .toList();
    final recentItems = visibleItems
        .where((item) => !item.isActionRequired)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 720
            ? (constraints.maxWidth - 680) / 2
            : AppSpacing.xl;

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.lg,
              horizontalPadding,
              AppSpacing.xl3,
            ),
            children: [
              NotificationInboxFilterBar(
                selected: filter,
                totalCount: inbox.length,
                unreadCount: unreadCount,
                onChanged: onFilterChanged,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (visibleItems.isEmpty)
                SizedBox(
                  height: (constraints.maxHeight - 132)
                      .clamp(260.0, 560.0)
                      .toDouble(),
                  child: NotificationInboxEmpty(
                    unreadOnly: filter == NotificationInboxFilter.unread,
                  ),
                )
              else ...[
                if (actionItems.isNotEmpty) ...[
                  _InboxSectionHeader(
                    title: NotificationStrings.actionRequiredSection,
                    count: actionItems.length,
                    emphasized: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._spacedCards(actionItems),
                  const SizedBox(height: AppSpacing.xl2),
                ],
                if (recentItems.isNotEmpty) ...[
                  _InboxSectionHeader(
                    title: NotificationStrings.recentSection,
                    count: recentItems.length,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._spacedCards(recentItems),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _spacedCards(List<NotificationInboxItem> items) {
    return [
      for (var index = 0; index < items.length; index++) ...[
        NotificationInboxCard(
          item: items[index],
          onTap: () => onItemTap(items[index]),
        ),
        if (index != items.length - 1) const SizedBox(height: AppSpacing.md),
      ],
    ];
  }
}

class _InboxSectionHeader extends StatelessWidget {
  const _InboxSectionHeader({
    required this.title,
    required this.count,
    this.emphasized = false,
  });

  final String title;
  final int count;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? AppColors.accent : AppColors.textSecondary;
    return Semantics(
      header: true,
      child: Row(
        children: [
          if (emphasized) ...[
            const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOutNotificationsView extends StatelessWidget {
  const _SignedOutNotificationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          NotificationStrings.screenTitle,
          style: AppTextStyles.headingMedium,
        ),
        backgroundColor: AppColors.bgCard,
      ),
      body: Center(
        child: Text(
          NotificationStrings.signInRequired,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
