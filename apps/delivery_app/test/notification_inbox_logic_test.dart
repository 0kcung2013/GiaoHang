import 'package:delivery_app/core/models/notification_model.dart';
import 'package:delivery_app/core/services/notification_service.dart';
import 'package:delivery_app/features/notifications/models/notification_inbox_item.dart';
import 'package:delivery_app/features/notifications/utils/notification_time_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notification inbox', () {
    test('groups order updates into one thread with newest event first', () {
      final inbox = buildNotificationInbox([
        _notification(
          id: 'older',
          orderId: 'order-1',
          title: 'Tài xế đã nhận đơn',
          createdAt: DateTime.utc(2026, 7, 30, 8),
        ),
        _notification(
          id: 'newer',
          orderId: 'order-1',
          title: 'Đang giao hàng',
          createdAt: DateTime.utc(2026, 7, 30, 9),
        ),
        _notification(
          id: 'system',
          type: NotificationTypes.system,
          title: 'Bảo trì hệ thống',
          createdAt: DateTime.utc(2026, 7, 30, 7),
        ),
      ], audience: NotificationAudience.customer);

      expect(inbox, hasLength(2));
      expect(inbox.first.orderId, 'order-1');
      expect(inbox.first.updateCount, 2);
      expect(inbox.first.latest.id, 'newer');
      expect(inbox.first.unreadCount, 2);
    });

    test('only unread driver offers require action', () {
      final driverInbox = buildNotificationInbox([
        _notification(
          id: 'offer',
          orderId: 'order-2',
          title: 'Đơn hàng mới gần bạn',
        ),
      ], audience: NotificationAudience.driver);
      final customerInbox = buildNotificationInbox([
        _notification(
          id: 'offer',
          orderId: 'order-2',
          title: 'Đơn hàng mới gần bạn',
        ),
      ], audience: NotificationAudience.customer);
      final readDriverInbox = buildNotificationInbox([
        _notification(
          id: 'offer',
          orderId: 'order-2',
          title: 'Đơn hàng mới gần bạn',
          isRead: true,
        ),
      ], audience: NotificationAudience.driver);

      expect(driverInbox.single.isActionRequired, isTrue);
      expect(customerInbox.single.isActionRequired, isFalse);
      expect(readDriverInbox.single.isActionRequired, isFalse);
    });

    test('latest cancellation replaces an older actionable offer', () {
      final inbox = buildNotificationInbox([
        _notification(
          id: 'offer',
          orderId: 'order-3',
          title: 'Đơn hàng mới gần bạn',
          createdAt: DateTime.utc(2026, 7, 30, 8),
        ),
        _notification(
          id: 'cancelled',
          orderId: 'order-3',
          title: 'Đơn hàng đã bị huỷ',
          createdAt: DateTime.utc(2026, 7, 30, 9),
        ),
      ], audience: NotificationAudience.driver);

      expect(inbox.single.visualKind, NotificationVisualKind.cancellation);
      expect(inbox.single.isActionRequired, isFalse);
    });
  });

  group('notification delivery policy', () {
    test('allows only customer-facing delivery milestones', () {
      expect(
        NotificationDeliveryPolicy.shouldNotifyCustomerStatus('picking_up'),
        isTrue,
      );
      expect(
        NotificationDeliveryPolicy.shouldNotifyCustomerStatus('delivering'),
        isTrue,
      );
      expect(
        NotificationDeliveryPolicy.shouldNotifyCustomerStatus('delivered'),
        isTrue,
      );
      expect(
        NotificationDeliveryPolicy.shouldNotifyCustomerStatus('assigned'),
        isFalse,
      );
      expect(
        NotificationDeliveryPolicy.shouldNotifyCustomerStatus('confirmed'),
        isFalse,
      );
    });
  });

  test('formats notification time for recent updates', () {
    final now = DateTime(2026, 7, 30, 10);
    expect(
      formatNotificationTime(DateTime(2026, 7, 30, 9, 45), now: now),
      '15 phút trước',
    );
  });
}

NotificationModel _notification({
  required String id,
  required String title,
  String type = NotificationTypes.orderUpdate,
  String? orderId,
  bool isRead = false,
  DateTime? createdAt,
}) {
  return NotificationModel(
    id: id,
    userId: 'user-1',
    title: title,
    body: 'Nội dung cập nhật',
    type: type,
    isRead: isRead,
    orderId: orderId,
    createdAt: createdAt ?? DateTime.utc(2026, 7, 30, 10),
  );
}
