import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/providers/customer_providers.dart';
import '../screens/notifications_screen.dart';

/// Nút chuông + badge số chưa đọc. Subscribe realtime khi có user.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

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
      tooltip: 'Thông báo',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ),
        ).then((_) {
          ref.invalidate(notificationsProvider(user.id));
          ref.invalidate(unreadNotificationCountProvider(user.id));
        });
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.accent,
        label: Text(
          unread > 99 ? '99+' : '$unread',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
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
