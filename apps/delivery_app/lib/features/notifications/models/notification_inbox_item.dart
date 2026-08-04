import '../../../core/models/notification_model.dart';
import '../../../core/services/notification_service.dart';

enum NotificationAudience { customer, driver }

enum NotificationVisualKind {
  orderOffer,
  orderProgress,
  success,
  cancellation,
  system,
  promotion,
}

class NotificationInboxItem {
  const NotificationInboxItem({
    required this.key,
    required this.notifications,
    required this.audience,
    required this.visualKind,
    required this.isActionRequired,
  });

  final String key;
  final List<NotificationModel> notifications;
  final NotificationAudience audience;
  final NotificationVisualKind visualKind;
  final bool isActionRequired;

  NotificationModel get latest => notifications.first;

  String? get orderId => latest.orderId;

  DateTime get lastUpdatedAt => latest.createdAt;

  bool get isUnread => notifications.any((item) => !item.isRead);

  int get unreadCount => notifications.where((item) => !item.isRead).length;

  int get updateCount => notifications.length;

  List<String> get unreadIds => [
    for (final item in notifications)
      if (!item.isRead) item.id,
  ];
}

List<NotificationInboxItem> buildNotificationInbox(
  List<NotificationModel> notifications, {
  required NotificationAudience audience,
}) {
  final groups = <String, List<NotificationModel>>{};

  for (final notification in notifications) {
    final orderId = notification.orderId?.trim();
    final key = orderId == null || orderId.isEmpty
        ? 'notification:${notification.id}'
        : 'order:$orderId';
    groups.putIfAbsent(key, () => <NotificationModel>[]).add(notification);
  }

  final inbox = groups.entries.map((entry) {
    final events = [...entry.value]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = events.first;
    return NotificationInboxItem(
      key: entry.key,
      notifications: List.unmodifiable(events),
      audience: audience,
      visualKind: _visualKindFor(latest),
      isActionRequired: _isActionRequired(latest, audience),
    );
  }).toList();

  inbox.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
  return inbox;
}

bool _isActionRequired(
  NotificationModel notification,
  NotificationAudience audience,
) {
  if (audience != NotificationAudience.driver || notification.isRead) {
    return false;
  }

  final title = notification.title.toLowerCase();
  return title.contains('đơn hàng mới') ||
      title.contains('gần bạn') ||
      title.contains('chuyển đến bạn');
}

NotificationVisualKind _visualKindFor(NotificationModel notification) {
  final title = notification.title.toLowerCase();

  if (title.contains('huỷ') || title.contains('hủy')) {
    return NotificationVisualKind.cancellation;
  }
  if (title.contains('đơn hàng mới') ||
      title.contains('gần bạn') ||
      title.contains('chuyển đến bạn')) {
    return NotificationVisualKind.orderOffer;
  }
  if (title.contains('thành công') || title.contains('đã nhận đơn')) {
    return NotificationVisualKind.success;
  }

  return switch (notification.type) {
    NotificationTypes.system => NotificationVisualKind.system,
    NotificationTypes.promotion => NotificationVisualKind.promotion,
    _ => NotificationVisualKind.orderProgress,
  };
}
