import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/support/data/support_completion_repository.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/dialogs/support_ticket_detail_dialog.dart';
import 'package:operations_web/features/support/models/support_completion_context.dart';

void main() {
  testWidgets('guidance remains scrollable on short web with enlarged text', (
    tester,
  ) async {
    final repo = _Repository()
      ..completion = const SupportCompletionContext(
        blockers: [SupportCompletionBlocker('Hàng đang chờ bàn giao.', 'risk')],
      );
    await _pump(tester, repo);
    tester.view.physicalSize = const Size(540, 640);
    await tester.pumpWidget(_app(repo, textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông tin hồ sơ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Việc cần làm'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(IndexedStack),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    expect(find.text('Việc cần làm'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Xử lý việc còn lại'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(IndexedStack),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.ensureVisible(find.text('Xử lý việc còn lại'));
    await tester.pumpAndSettle();
    expect(find.text('Xử lý việc còn lại').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('completion mirrors custody rules without requiring delivery', () {
    expect(
      SupportCompletionContext.fromRows(orderStatus: 'delivering').blockers,
      isEmpty,
    );
    expect(
      SupportCompletionContext.fromRows(
        risk: {'id': 'risk', 'status': 'dismissed'},
      ).blockers,
      isEmpty,
    );
    final result = SupportCompletionContext.fromRows(
      risk: {'id': 'risk', 'status': 'investigating'},
      interventions: [
        {'risk_report_id': 'return', 'state': 'return_required'},
        {'risk_report_id': 'handoff', 'state': 'handoff_required'},
        {'risk_report_id': 'done', 'state': 'completed'},
      ],
    );
    expect(result.blockers.map((b) => b.riskReportId), [
      'risk',
      'return',
      'handoff',
    ]);
  });

  testWidgets('shows custody blocker before finish; refresh unlocks it', (
    tester,
  ) async {
    final repo = _Repository()
      ..completion = const SupportCompletionContext(
        blockers: [SupportCompletionBlocker('Hàng đang chờ bàn giao.', 'risk')],
      );
    await _pump(tester, repo);
    expect(_finish(tester).onPressed, isNull);
    expect(find.text('Hàng đang chờ bàn giao.'), findsOneWidget);
    expect(find.text('Xử lý việc còn lại'), findsOneWidget);
    repo.completion = const SupportCompletionContext(orderStatus: 'delivering');
    await _refresh(tester);
    await tester.pumpAndSettle();
    expect(_finish(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('finish-support-ticket')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-resolution-field')), findsOneWidget);
  });

  testWidgets(
    'failed preflight disables finish and retries without losing draft',
    (tester) async {
      final repo = _Repository()..failCompletion = true;
      await _pump(tester, repo);
      expect(_finish(tester).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('support-case-message-field')),
        'Bản nháp còn nguyên',
      );
      repo.failCompletion = false;
      await _refresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('Bản nháp còn nguyên'), findsOneWidget);
      expect(_finish(tester).onPressed, isNotNull);
    },
  );

  testWidgets('finish rechecks obligations created after opening the case', (
    tester,
  ) async {
    final repo = _Repository();
    await _pump(tester, repo);
    repo.completion = const SupportCompletionContext(
      blockers: [SupportCompletionBlocker('Hàng đang chờ hoàn.', 'risk')],
    );
    await tester.tap(find.byKey(const Key('finish-support-ticket')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-resolution-field')), findsNothing);
    expect(repo.transitions, 0);
    expect(_finish(tester).onPressed, isNull);
  });

  testWidgets(
    'template is editable, never sent automatically, and survives resize',
    (tester) async {
      final repo = _Repository();
      await _pump(tester, repo);
      await tester.tap(find.text('Dùng mẫu trả lời · sửa trước khi gửi'));
      await tester.pumpAndSettle();
      expect(repo.sent, isEmpty);
      final field = find.byKey(const Key('support-case-message-field'));
      expect(
        tester.widget<TextField>(field).controller!.text,
        contains('các lần đã liên hệ'),
      );
      await tester.enterText(field, 'Nội dung đã chỉnh sửa');
      tester.view.physicalSize = const Size(540, 640);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Nội dung đã chỉnh sửa',
      );
      await tester.tap(find.text('Thông tin hồ sơ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trao đổi'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Nội dung đã chỉnh sửa',
      );
      await tester.ensureVisible(
        find.byKey(const Key('send-support-case-message')),
      );
      await tester.tap(find.byKey(const Key('send-support-case-message')));
      await tester.pumpAndSettle();
      expect(repo.sent, ['Nội dung đã chỉnh sửa']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('message stream failure is not hidden by refreshing the ticket', (
    tester,
  ) async {
    final repo = _Repository();
    await _pump(tester, repo);
    repo.messages.addError(StateError('offline'));
    await tester.pumpAndSettle();
    repo.ticketChanges.add(null);
    await tester.pumpAndSettle();
    expect(
      find.text('Mất kết nối hội thoại. Vui lòng thử lại.'),
      findsOneWidget,
    );
    await _refresh(tester);
    await tester.pumpAndSettle();
    repo.messages.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối hội thoại. Vui lòng thử lại.'), findsNothing);
  });
}

FilledButton _finish(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('finish-support-ticket')));

Future<void> _refresh(WidgetTester tester) async {
  // Stream cancellation may complete in the real async zone.
  await tester.runAsync(() async {
    await tester.tap(find.byTooltip('Tải lại hồ sơ'));
    await Future<void>.delayed(Duration.zero);
  });
}

Future<void> _pump(WidgetTester tester, _Repository repo) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(repo.messages.close);
  addTearDown(repo.ticketChanges.close);
  await tester.pumpWidget(_app(repo));
  await tester.pumpAndSettle();
}

Widget _app(_Repository repo, {double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: SupportTicketDetailDialog(
      ticket: repo.ticket,
      currentUserId: 'staff',
      isAdmin: false,
      repository: repo,
      completionRepository: repo,
    ),
  ),
);

class _Repository
    implements
        SupportTicketRepository,
        SupportTicketDetailRepository,
        SupportTicketCommandRepository,
        SupportTicketConversationRepository,
        SupportCompletionRepository {
  final messages = StreamController<List<CaseMessage>>.broadcast();
  final ticketChanges = StreamController<void>.broadcast();
  final sent = <String>[];
  bool failCompletion = false;
  int transitions = 0;
  SupportCompletionContext completion = const SupportCompletionContext();
  final ticket = SupportTicket(
    id: 'ticket',
    requesterId: 'driver',
    requesterRole: 'driver',
    subject: SupportIssue.recipientUnavailable.subject,
    message: 'Đã gọi ba lần, chưa có phản hồi.',
    status: SupportTicketStatus.inProgress,
    assignedTo: 'staff',
    priority: SupportTicketPriority.high,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  @override
  Future<SupportCompletionContext> fetchCompletionContext(
    SupportTicket ticket,
  ) async {
    if (failCompletion) throw StateError('offline');
    return completion;
  }

  @override
  Future<SupportTicket> fetchTicket(String id) async => ticket;
  @override
  Stream<void> watchTicket(String id) => ticketChanges.stream;
  @override
  Future<List<SupportTicket>> fetchTickets() async => [ticket];
  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {}
  @override
  Future<void> updateStatus(String id, SupportTicketStatus status) async {}
  @override
  Future<void> acceptTicket(String id) async {}
  @override
  Future<void> takeOverTicket(String id) async {}
  @override
  Future<void> transitionTicket(
    String id,
    SupportTicketStatus status, {
    String? resolution,
  }) async {
    transitions++;
  }

  @override
  Future<List<CaseMessage>> fetchMessages(String id) async => [];
  @override
  Stream<List<CaseMessage>> watchMessages(String id) => messages.stream;
  @override
  Future<void> postMessage(
    String id,
    String body, {
    required CaseMessageVisibility visibility,
  }) async {
    sent.add(body);
  }
}
