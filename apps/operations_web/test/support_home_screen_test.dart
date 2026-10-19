import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support/screens/support_home_screen.dart';

void main() {
  for (final monitoring in [false, true]) {
    testWidgets('queue separates monitoring=$monitoring including counts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: SupportHomeScreen(
            repository: _MixedRepository(),
            currentUserId: 'support-1',
            monitoring: monitoring,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Giám sát: thu hồi phân công'),
        monitoring ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Kiểm tra thanh toán COD'),
        monitoring ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(monitoring ? 'Cần can thiệp · 1' : 'Cần xử lý · 2'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create-support-ticket-button')),
        monitoring ? findsNothing : findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('support-queue-finished')));
      await tester.pumpAndSettle();
      expect(
        find.text('Giám sát: cần xác minh hành trình'),
        monitoring ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Yêu cầu đã giải quyết'),
        monitoring ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('monitoring stays classified after staff or customer reply', () {
    for (final role in ['system', 'support', 'customer', 'driver']) {
      final ticket = SupportTicket.fromJson({
        'subject': 'Giám sát: thu hồi phân công',
        'last_message_role': role,
      });
      expect(ticket.isMonitoring, isTrue);
    }
    expect(
      SupportTicket.fromJson({
        'subject': 'Hỗ trợ đơn hàng',
        'last_message_role': 'system',
      }).isMonitoring,
      isFalse,
    );
  });
  testWidgets('filters expose unassigned and reply work independently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
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
    await tester.tap(find.byKey(const Key('support-queue-unassigned')));
    await tester.pumpAndSettle();
    expect(find.text('Không liên lạc được khách'), findsOneWidget);
    expect(find.text('Kiểm tra thanh toán COD'), findsNothing);
    await tester.tap(find.byKey(const Key('support-queue-needsReply')));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra thanh toán COD'), findsOneWidget);
    expect(find.text('Không liên lạc được khách'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('support-ticket-search')),
      'không có',
    );
    await tester.pumpAndSettle();
    expect(find.text('0 hồ sơ phù hợp'), findsOneWidget);
  });

  testWidgets(
    'failed refresh keeps existing results and search, retry recovers',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _RefreshingRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: SupportHomeScreen(
            repository: repository,
            currentUserId: 'support-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('support-ticket-search')),
        'thanh toán',
      );
      await tester.pumpAndSettle();
      repository.fail = true;
      await tester.tap(find.byTooltip('Tải lại danh sách'));
      await tester.pumpAndSettle();
      expect(find.text('Kiểm tra thanh toán COD'), findsOneWidget);
      expect(find.textContaining('Chưa cập nhật được.'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa cập nhật được.'), findsNothing);
      expect(find.text('Kiểm tra thanh toán COD'), findsOneWidget);
      expect(find.text('Không liên lạc được khách'), findsNothing);
    },
  );

  testWidgets('older realtime response cannot overwrite newer queue', (
    tester,
  ) async {
    final repository = _ConcurrentRepository();
    addTearDown(repository.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SupportHomeScreen(
          repository: repository,
          currentUserId: 'support-1',
        ),
      ),
    );
    await tester.pump();
    repository.changes.add(null);
    await tester.pump();
    final tickets = await _FakeSupportTicketRepository().fetchTickets();
    repository.requests[1].complete([tickets[1]]);
    await tester.pumpAndSettle();
    repository.requests[0].complete([tickets[0]]);
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra thanh toán COD'), findsOneWidget);
    expect(find.text('Không liên lạc được khách'), findsNothing);
  });

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
    await tester.scrollUntilVisible(
      find.byKey(const Key('support-ticket-search')),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('support-ticket-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
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
    expect(find.text('Quá hạn phản hồi'), findsNothing);
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
      subject: 'Không liên lạc được khách',
      responseDueAt: DateTime(2020),
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
      lastMessageRole: 'customer',
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

class _MixedRepository extends _FakeSupportTicketRepository {
  @override
  Future<List<SupportTicket>> fetchTickets() async => [
    ...await super.fetchTickets(),
    SupportTicket.fromJson({
      'id': 'monitor-active',
      'subject': 'Giám sát: thu hồi phân công',
      'status': 'open',
      'last_message_role': 'support',
    }),
    SupportTicket.fromJson({
      'id': 'monitor-closed',
      'subject': 'Giám sát: cần xác minh hành trình',
      'status': 'closed',
    }),
  ];
}

class _RefreshingRepository extends _FakeSupportTicketRepository {
  bool fail = false;
  @override
  Future<List<SupportTicket>> fetchTickets() async {
    if (fail) throw StateError('offline');
    return super.fetchTickets();
  }
}

class _ConcurrentRepository extends _FakeSupportTicketRepository
    implements SupportTicketChangesRepository {
  final changes = StreamController<void>();
  final requests = <Completer<List<SupportTicket>>>[];
  @override
  Stream<void> watchTicketChanges() => changes.stream;
  @override
  Future<List<SupportTicket>> fetchTickets() {
    final request = Completer<List<SupportTicket>>();
    requests.add(request);
    return request.future;
  }
}
