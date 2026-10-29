import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:operations_web/features/support/widgets/support_workspace_scaffold.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support/notifications/support_request_alerts_controller.dart';
import 'package:operations_web/features/support/notifications/support_request_alerts_repository.dart';
import 'package:operations_web/features/support/notifications/support_request_alerts_host.dart';
import 'package:operations_web/features/support/notifications/support_request_bell.dart';

void main() {
  test(
    'Admin alerts only escalated work, including a case still assigned to Support',
    () async {
      final repository = _AlertsRepository();
      final admin = SupportRequestAlertsController(
        repository,
        adminDecisionsOnly: true,
      );
      final support = SupportRequestAlertsController(repository);
      addTearDown(() async {
        admin.dispose();
        support.dispose();
        await repository.close();
      });
      repository.emit([_ticket('ordinary')]);
      await Future<void>.delayed(Duration.zero);
      expect(admin.unreadCount, 0);
      expect(support.unreadCount, 1);
      repository.emit([_ticket('ordinary'), _escalated('decision')]);
      await Future<void>.delayed(Duration.zero);
      expect(admin.unreadCount, 1);
      expect(admin.latest?.id, 'decision');
      expect(support.unreadCount, 1);
      expect(support.latest, isNull);
      admin.markRead('decision');
      repository.emit([_ticket('ordinary')]);
      await Future<void>.delayed(Duration.zero);
      expect(admin.unreadCount, 0);
      repository.emit([_escalated('decision')]);
      await Future<void>.delayed(Duration.zero);
      expect(admin.unreadCount, 1);
      expect(admin.latest?.id, 'decision');
    },
  );

  testWidgets(
    'Admin escalation toast ignores normal requests and opens the Admin case',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _AlertsRepository();
      final router = GoRouter(
        initialLocation: '/admin-home',
        routes: [
          ShellRoute(
            builder: (_, _, child) => SupportRequestAlertsHost(
              repository: repository,
              adminDecisionsOnly: true,
              child: child,
            ),
            routes: [
              GoRoute(
                path: '/admin-home',
                builder: (_, _) => const Scaffold(body: SupportRequestBell()),
              ),
              GoRoute(
                path: '/admin-ticket/:id',
                builder: (_, state) =>
                    Scaffold(body: Text('Admin ${state.pathParameters['id']}')),
              ),
            ],
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        await repository.close();
      });
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
        ),
      );
      repository.emit([_ticket('normal')]);
      await tester.pumpAndSettle();
      expect(find.text('Có yêu cầu hỗ trợ mới'), findsNothing);
      repository.emit([_ticket('normal'), _escalated('decision')]);
      await tester.pumpAndSettle();
      expect(find.text('Có hồ sơ cần Admin quyết định'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Xem hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.text('Admin decision'), findsOneWidget);
      expect(repository.watches, 1);
    },
  );

  test(
    'automatic reclamation stays silent; a subsequent real request surfaces',
    () async {
      final repository = _AlertsRepository();
      final controller = SupportRequestAlertsController(repository);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      const body =
          'Chưa nhận hàng. Hệ thống thu hồi phân công và tìm tài xế thay thế.';
      final automatic = SupportTicket.fromJson({
        'id': 'auto',
        'requester_id': 'driver',
        'subject': 'Giám sát: thu hồi phân công',
        'message': body,
        'last_message_role': 'system',
        'status': 'open',
      });
      repository.emit([]);
      await Future<void>.delayed(Duration.zero);
      repository.emit([automatic]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.unreadCount, 0);
      expect(controller.latest, isNull);
      repository.emit([
        SupportTicket.fromJson({
          ...automatic.toJson(),
          'has_human_conversation': true,
        }),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.unreadCount, 1);
      expect(controller.latest?.id, 'auto');
    },
  );
  testWidgets(
    'toast fits small viewport, expires, and leaves unread badge until accepted',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _AlertsRepository();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await repository.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: SupportRequestAlertsHost(
            repository: repository,
            child: const SupportWorkspaceScaffold(
              activeSection: SupportWorkspaceSection.orders,
              body: SizedBox(),
            ),
          ),
        ),
      );
      repository.emit([]);
      await tester.pumpAndSettle();
      repository.emit([_ticket('new')]);
      await tester.pumpAndSettle();
      expect(find.text('Có yêu cầu hỗ trợ mới'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final controller = SupportRequestAlertsScope.maybeOf(
        tester.element(find.byType(SupportRequestBell)),
      )!;
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('Có yêu cầu hỗ trợ mới'), findsNothing);
      expect(controller.unreadCount, 1);
      repository.emit([]);
      await tester.pumpAndSettle();
      expect(controller.unreadCount, 0);
    },
  );
  test(
    'initial pending requests get a badge, only new IDs produce a toast',
    () async {
      final repository = _AlertsRepository();
      final controller = SupportRequestAlertsController(repository);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      repository.emit([_ticket('old')]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.unreadCount, 1);
      expect(controller.latest, isNull);
      repository.emit([_ticket('old'), _ticket('new')]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.unreadCount, 2);
      expect(controller.latest?.id, 'new');
      controller.dismissToast();
      repository.emit([_ticket('old'), _ticket('new')]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.latest, isNull);
      controller.markRead('new');
      expect(controller.unreadCount, 1);
      repository.emit([_ticket('old')]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.requests.map((item) => item.id), ['old']);
      controller.markAllRead();
      expect(controller.unreadCount, 0);
    },
  );

  test(
    'failure preserves requests and reconnect does not replay old alerts',
    () async {
      final repository = _AlertsRepository();
      final controller = SupportRequestAlertsController(repository);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      repository.emit([_ticket('old')]);
      await Future<void>.delayed(Duration.zero);
      repository.stream.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.failed, isTrue);
      expect(controller.unreadCount, 1);
      controller.reconnect();
      repository.emit([_ticket('old'), _ticket('missed')]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.failed, isFalse);
      expect(controller.latest?.id, 'missed');
      expect(repository.watches, 2);
    },
  );

  testWidgets(
    'new request notification survives navigation and opens the correct case',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _AlertsRepository();
      final router = GoRouter(
        initialLocation: '/support-home',
        routes: [
          ShellRoute(
            builder: (_, _, child) =>
                SupportRequestAlertsHost(repository: repository, child: child),
            routes: [
              GoRoute(
                path: '/support-home',
                builder: (_, _) => const SupportWorkspaceScaffold(
                  activeSection: SupportWorkspaceSection.tickets,
                  body: Text('Chat page'),
                ),
              ),
              GoRoute(
                path: '/support-orders',
                builder: (_, _) => const SupportWorkspaceScaffold(
                  activeSection: SupportWorkspaceSection.orders,
                  body: Text('Order page'),
                ),
              ),
              GoRoute(
                path: '/support-ticket/:id',
                builder: (_, state) =>
                    Scaffold(body: Text('Case ${state.pathParameters['id']}')),
              ),
            ],
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        await repository.close();
      });
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      repository.emit([]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tra cứu đơn'));
      await tester.pumpAndSettle();
      repository.emit([_ticket('new')]);
      await tester.pumpAndSettle();
      expect(find.text('Có yêu cầu hỗ trợ mới'), findsOneWidget);
      expect(repository.watches, 1);
      final controller = SupportRequestAlertsScope.maybeOf(
        tester.element(find.byType(SupportRequestBell)),
      );
      expect(controller?.unreadCount, 1);
      await tester.tap(find.text('Xem yêu cầu'));
      await tester.pumpAndSettle();
      expect(find.text('Case new'), findsOneWidget);
      expect(controller?.unreadCount, 0);
      expect(repository.watches, 1);
    },
  );

  testWidgets('bell inbox supports narrow viewport and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _AlertsRepository();
    final controller = SupportRequestAlertsController(repository);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await repository.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: SupportRequestAlertsScope(
          controller: controller,
          child: const SupportWorkspaceScaffold(
            activeSection: SupportWorkspaceSection.orders,
            body: SizedBox(),
          ),
        ),
      ),
    );
    repository.emit([_ticket('monitor', monitoring: true)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yêu cầu mới'));
    await tester.pumpAndSettle();
    expect(find.text('Giám sát: thu hồi phân công'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Đánh dấu tất cả đã xem'));
    await tester.pumpAndSettle();
    expect(controller.unreadCount, 0);
  });

  testWidgets('CSKH can see the new request notification entry on desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: SupportWorkspaceScaffold(
          activeSection: SupportWorkspaceSection.orders,
          body: SizedBox(),
        ),
      ),
    );
    expect(find.byTooltip('Yêu cầu mới'), findsOneWidget);
  });
}

SupportTicket _escalated(String id) => SupportTicket.fromJson({
  ..._ticket(id).toJson(),
  'status': 'waiting_admin',
  'assigned_to': 'support-1',
});

SupportTicket _ticket(String id, {bool monitoring = false}) => SupportTicket(
  id: id,
  requesterId: 'customer',
  subject: monitoring ? 'Giám sát: thu hồi phân công' : 'Yêu cầu $id',
  message: 'Tôi cần hỗ trợ về tài khoản.',
  status: SupportTicketStatus.open,
  priority: SupportTicketPriority.normal,
  createdAt: id == 'old' ? DateTime(2025) : DateTime(2026),
  updatedAt: DateTime(2026),
);

class _AlertsRepository implements SupportRequestAlertsRepository {
  final stream = StreamController<List<SupportTicket>>.broadcast();
  int watches = 0;
  void emit(List<SupportTicket> tickets) => stream.add(tickets);
  Future<void> close() => stream.close();
  @override
  Stream<List<SupportTicket>> watchOpenRequests() {
    watches++;
    return stream.stream;
  }
}
