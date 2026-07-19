import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/services/notification_service.dart';

/// Màn danh sách thông báo in-app (customer + driver dùng chung).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(
          title: Text('Thông báo', style: AppTextStyles.headingMedium),
          backgroundColor: AppColors.bgCard,
        ),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    ref.watch(notificationsRealtimeProvider(user.id));
    final listAsync = ref.watch(notificationsProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          'Thông báo',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(notificationServiceProvider)
                  .markAllAsRead(user.id);
              ref.invalidate(notificationsProvider(user.id));
              ref.invalidate(unreadNotificationCountProvider(user.id));
            },
            child: Text(
              'Đọc hết',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Không tải được thông báo',
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(notificationsProvider(user.id)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Chưa có thông báo',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Khi có đơn mới hoặc cập nhật trạng thái, thông báo sẽ hiện ở đây.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider(user.id));
              ref.invalidate(unreadNotificationCountProvider(user.id));
              await ref.read(notificationsProvider(user.id).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationTile(
                  notification: item,
                  onTap: () async {
                    if (!item.isRead) {
                      await ref
                          .read(notificationServiceProvider)
                          .markAsRead(item.id, user.id);
                      ref.invalidate(notificationsProvider(user.id));
                      ref.invalidate(unreadNotificationCountProvider(user.id));
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final iconData = _iconForType(notification.type);
    final iconColor = _colorForType(notification.type);

    return Material(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: unread
                  ? AppColors.accent.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
            boxShadow: AppShadow.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.body,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    // DB chỉ có order_update / system / promotion — phân biệt thêm qua title.
    final title = notification.title.toLowerCase();
    if (title.contains('huỷ') || title.contains('hủy')) {
      return Icons.cancel_rounded;
    }
    if (title.contains('chuyển')) return Icons.swap_horiz_rounded;
    if (title.contains('nhận đơn') || title.contains('thành công')) {
      return Icons.check_circle_rounded;
    }
    if (title.contains('mới') || title.contains('gần bạn')) {
      return Icons.local_shipping_rounded;
    }
    return switch (type) {
      NotificationTypes.orderUpdate => Icons.info_rounded,
      NotificationTypes.system => Icons.settings_rounded,
      NotificationTypes.promotion => Icons.local_offer_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  Color _colorForType(String type) {
    final title = notification.title.toLowerCase();
    if (title.contains('huỷ') || title.contains('hủy')) return AppColors.error;
    if (title.contains('chuyển')) return AppColors.warning;
    if (title.contains('nhận đơn') || title.contains('thành công')) {
      return AppColors.success;
    }
    if (title.contains('mới') || title.contains('gần bạn')) {
      return AppColors.info;
    }
    return switch (type) {
      NotificationTypes.orderUpdate => AppColors.accent,
      NotificationTypes.system => AppColors.textMuted,
      NotificationTypes.promotion => AppColors.warning,
      _ => AppColors.textMuted,
    };
  }

  String _timeAgo(DateTime dt) {
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }
}
