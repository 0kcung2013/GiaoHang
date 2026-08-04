import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../core/providers/customer_providers.dart';
import '../models/notification_inbox_item.dart';
import '../notification_strings.dart';
import '../screens/notifications_screen.dart';

/// Nút chuông + badge số luồng thông báo chưa đọc.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key, required this.audience});

  final NotificationAudience audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return IconButton(
        onPressed: null,
        icon: Icon(
          Icons.notifications_none_rounded,
          color: AppColors.textMuted,
        ),
      );
    }

    ref.watch(notificationsRealtimeProvider(user.id));
    final unreadAsync = ref.watch(unreadNotificationCountProvider(user.id));
    final unread = unreadAsync.valueOrNull ?? 0;

    return IconButton(
      tooltip: NotificationStrings.notificationTooltip,
      onPressed: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(audience: audience),
              ),
            )
            .then((_) {
              ref.invalidate(notificationsProvider(user.id));
              ref.invalidate(unreadNotificationCountProvider(user.id));
            });
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.accent,
        label: Text(
          unread > 9 ? '9+' : '$unread',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textOnAccent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        child: Icon(
          unread > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
