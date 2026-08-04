import 'package:delivery_app/core/models/notification_model.dart';
import 'package:delivery_app/core/services/notification_service.dart';
import 'package:delivery_app/features/notifications/models/notification_inbox_item.dart';
import 'package:delivery_app/features/notifications/widgets/notification_inbox_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('notification card supports small phones and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final item = buildNotificationInbox([
      NotificationModel(
        id: 'newer',
        userId: 'driver-1',
        title: 'Đơn hàng mới gần bạn',
        body:
            'Đơn GH-123456 cần lấy tại 12 Nguyễn Huệ, Quận 1, Thành phố Hồ Chí Minh.',
        type: NotificationTypes.orderUpdate,
        isRead: false,
        orderId: 'order-1',
        createdAt: DateTime.utc(2026, 7, 30, 10),
      ),
      NotificationModel(
        id: 'older',
        userId: 'driver-1',
        title: 'Đơn được chuyển đến bạn',
        body: 'Khách hàng đang chờ tài xế nhận đơn.',
        type: NotificationTypes.orderUpdate,
        isRead: true,
        orderId: 'order-1',
        createdAt: DateTime.utc(2026, 7, 30, 9),
      ),
    ], audience: NotificationAudience.driver).single;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 812),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: NotificationInboxCard(item: item, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đơn hàng mới gần bạn'), findsOneWidget);
    expect(find.text('2 cập nhật'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
