import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support/screens/support_home_screen.dart';

void main() {
  testWidgets(
    'mine and completed views keep active and closed cases separate',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: SupportHomeScreen(
            repository: _FakeSupportTicketRepository(),
            currentUserId: 'support-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yêu cầu đã giải quyết'), findsNothing);
      await tester.tap(find.byKey(const Key('support-queue-mine')));
      await tester.pumpAndSettle();
      expect(find.text('Kiểm tra thanh toán COD'), findsOneWidget);
      expect(find.text('Không liên lạc được khách'), findsNothing);
      await tester.tap(find.byKey(const Key('support-queue-finished')));
      await tester.pumpAndSettle();
      expect(find.text('Yêu cầu đã giải quyết'), findsOneWidget);
      expect(find.text('Kiểm tra thanh toán COD'), findsNothing);
    },
  );

  testWidgets('short support workspace fits enlarged text', (tester) async {
    tester.view.physicalSize = const Size(375, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: SupportHomeScreen(
          repository: _FakeSupportTicketRepository(),
          currentUserId: 'support-1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Tra cứu đơn').hitTestable(), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('support-ticket-search')),
      'không có',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('support workspace keeps three views and searches the queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SupportHomeScreen(
          repository: _FakeSupportTicketRepository(),
          currentUserId: 'support-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CSKH'), findsOneWidget);
    expect(find.text('Chat hỗ trợ'), findsNWidgets(2));
    expect(find.byKey(const Key('support-queue-active')), findsOneWidget);
    expect(find.byKey(const Key('support-queue-mine')), findsOneWidget);
    expect(find.byKey(const Key('support-queue-finished')), findsOneWidget);
    expect(find.text('Quá hạn SLA'), findsNothing);
    expect(find.text('Ưu tiên cao'), findsOneWidget);
    expect(find.text('Không liên lạc được khách'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('support-ticket-search')),
      'thanh toán',
    );
    await tester.pump();

    expect(find.text('Không liên lạc được khách'), findsNothing);
    expect(find.text('Kiểm tra thanh toán COD'), findsOneWidget);
  });

  testWidgets('support workspace stays usable on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SupportHomeScreen(
          repository: _FakeSupportTicketRepository(),
          currentUserId: 'support-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CSKH'), findsOneWidget);
    expect(
      find.byKey(const Key('create-support-ticket-button')),
      findsOneWidget,
    );
    expect(find.text('Cần xử lý · 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('support-ticket-search')),
      'thanh toán',
    );
    await tester.pump();

    expect(find.byTooltip('Xóa tìm kiếm'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('Không liên lạc được khách'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeSupportTicketRepository implements SupportTicketRepository {
  @override
  Future<List<SupportTicket>> fetchTickets() async => [
    SupportTicket(
      id: 'ticket-1',
      requesterId: 'customer-1',
      requesterRole: 'customer',
      orderId: 'order-1',
      subject: 'Không liên lạc được khách',
      message: 'Tài xế cần CSKH xác minh số điện thoại.',
      status: SupportTicketStatus.open,
      priority: SupportTicketPriority.high,
      createdAt: DateTime(2026, 8, 12, 9),
      updatedAt: DateTime(2026, 8, 12, 10),
    ),
    SupportTicket(
      id: 'ticket-2',
      requesterId: 'customer-2',
      requesterRole: 'customer',
      subject: 'Kiểm tra thanh toán COD',
      message: 'Khách hàng cần đối soát khoản thu hộ.',
      status: SupportTicketStatus.inProgress,
      assignedTo: 'support-1',
      priority: SupportTicketPriority.normal,
      createdAt: DateTime(2026, 8, 12, 8),
      updatedAt: DateTime(2026, 8, 12, 11),
    ),
    SupportTicket(
      id: 'ticket-3',
      requesterId: 'customer-3',
      requesterRole: 'customer',
      subject: 'Yêu cầu đã giải quyết',
      message: 'Đã nhận hàng.',
      status: SupportTicketStatus.resolved,
      priority: SupportTicketPriority.normal,
      createdAt: DateTime(2026, 8, 11),
      updatedAt: DateTime(2026, 8, 11),
    ),
  ];

  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {}

  @override
  Future<void> updateStatus(
    String ticketId,
    SupportTicketStatus status,
  ) async {}
}
