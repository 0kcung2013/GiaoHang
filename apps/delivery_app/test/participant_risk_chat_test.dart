import 'dart:async';
import 'dart:convert';

import 'package:delivery_app/features/order_help/controllers/support_chat_attachment_draft.dart';
import 'package:delivery_app/features/order_help/widgets/support_chat/support_chat_messages.dart';
import 'package:delivery_app/features/risk_reports/controllers/risk_chat_controller.dart';
import 'package:delivery_app/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:delivery_app/features/risk_reports/models/participant_risk_report_summary.dart';
import 'package:delivery_app/features/risk_reports/utils/risk_chat_strings.dart';
import 'package:delivery_app/features/risk_reports/widgets/risk_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:image_picker/image_picker.dart';

final _created = DateTime.utc(2026, 10, 9, 6, 5);
ParticipantRiskReportSummary _report({String status = 'open'}) =>
    ParticipantRiskReportSummary.fromJson({
      'id': 'report-1',
      'order_id': 'order-1',
      'category': 'contact_issue',
      'status': status,
      'title': 'Không liên lạc được người nhận',
      'reported_by': 'driver',
      'reporter_role_snapshot': 'driver',
      'created_at': _created.toIso8601String(),
      'updated_at': _created.toIso8601String(),
    });

CaseMessage _message(
  String id,
  String body, {
  String caseId = 'report-1',
  String sender = 'support',
  CaseMessageVisibility visibility = CaseMessageVisibility.public,
}) => CaseMessage(
  id: id,
  caseId: caseId,
  senderId: sender,
  senderRole: sender,
  visibility: visibility,
  body: body,
  createdAt: _created,
);

void main() {
  test('refresh resubscribes after failed fetch', () async {
    final repository = _Repository()..failFetch = true;
    addTearDown(repository.close);
    final chat = RiskChatController(
      repository: repository,
      requesterId: 'driver',
      report: _report(),
    );
    addTearDown(chat.dispose);
    await chat.refresh();
    repository.failFetch = false;
    await chat.refresh();
    expect(repository.watchedIds, ['report-1', 'report-1']);
    repository.emit([_message('reply', 'Đã kết nối lại')]);
    await Future<void>.delayed(Duration.zero);
    expect(chat.messages!.single.body, 'Đã kết nối lại');
  });

  testWidgets('risk chat receives public replies for its report only', (
    tester,
  ) async {
    final repository = _Repository();
    addTearDown(repository.close);
    await _mount(tester, repository);
    final reply = _message('reply', 'CSKH đã nhận yêu cầu hoàn.');
    repository.emit([
      reply,
      reply,
      _message(
        'internal',
        'Ghi chú nội bộ',
        visibility: CaseMessageVisibility.internal,
      ),
      _message('other', 'Tin của báo cáo khác', caseId: 'other-report'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(reply.body), findsOneWidget);
    expect(find.text('Ghi chú nội bộ'), findsNothing);
    expect(find.text('Tin của báo cáo khác'), findsNothing);
    expect(repository.watchedIds, ['report-1']);
    expect(find.text(RiskChatStrings.subject), findsOneWidget);
  });

  testWidgets(
    'double tap sends once and Realtime replaces pending before HTTP failure',
    (tester) async {
      final repository = _Repository()
        ..delayPost = true
        ..failPost = true;
      addTearDown(repository.close);
      await _mount(tester, repository);
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'hello',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pump();
      expect(repository.posts, [('report-1', 'hello')]);
      final saved = _message('saved', 'hello', sender: 'driver');
      repository.emit([saved, saved]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('Đang gửi...'), findsNothing);
      repository.postGate.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('support-chat-composer')))
            .controller!
            .text,
        isEmpty,
      );
      expect(repository.posts, hasLength(1));
      // Hai tin cùng nội dung nhưng khác ID không bị mất.
      repository.emit([saved, _message('second', 'hello', sender: 'driver')]);
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsNWidgets(2));
    },
  );

  testWidgets('failed send keeps draft and retries in the same report', (
    tester,
  ) async {
    final repository = _Repository()..failPost = true;
    addTearDown(repository.close);
    await _mount(tester, repository);
    await tester.enterText(
      find.byKey(const Key('support-chat-composer')),
      'Khách gọi lại',
    );
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pumpAndSettle();
    expect(find.text(RiskChatStrings.sendError), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('support-chat-composer')))
          .controller!
          .text,
      'Khách gọi lại',
    );
    repository.failPost = false;
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pumpAndSettle();
    expect(repository.posts.map((p) => p.$1), ['report-1', 'report-1']);
    expect(repository.messages, hasLength(1));
  });

  testWidgets('closed report keeps history and disables reply', (tester) async {
    final repository = _Repository();
    addTearDown(repository.close);
    await _mount(tester, repository);
    repository.emit([_message('reply', 'Đã duyệt hoàn hàng')]);
    repository.value = _report(status: 'resolved');
    repository.reports.add(repository.value);
    await tester.pumpAndSettle();
    expect(find.text('Đã duyệt hoàn hàng'), findsOneWidget);
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(find.byKey(const Key('support-chat-composer')), findsNothing);
    expect(repository.posts, isEmpty);
  });

  testWidgets(
    'image send belongs to report and keeps existing attachment protocol',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
      );
      const uri =
          'r2://media/users/driver/order-cargo/order-1/support-chat/one.jpg';
      final draft = SupportChatAttachmentDraft(
        contextId: 'order-1',
        pickImages: () async => [XFile.fromData(png, name: 'photo.png')],
        prepareImage: (bytes) async => bytes,
        uploadImage: (_, contextId) async {
          expect(contextId, 'order-1');
          return uri;
        },
      );
      await _mount(tester, repository, attachments: draft);
      await tester.tap(find.byKey(const Key('attach-support-chat-image')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pumpAndSettle();
      expect(repository.posts.single.$1, 'report-1');
      expect(CaseMessageContent.decode(repository.posts.single.$2).images, [
        uri,
      ]);
      expect(draft.images, isEmpty);
    },
  );

  test(
    'late HTTP snapshot cannot overwrite Realtime reply or closed status',
    () async {
      final repository = _Repository()
        ..fetchGate = Completer<List<CaseMessage>>();
      addTearDown(repository.close);
      final chat = RiskChatController(
        repository: repository,
        requesterId: 'driver',
        report: _report(),
      );
      addTearDown(chat.dispose);
      final refresh = chat.refresh();
      await Future<void>.delayed(Duration.zero);
      final reply = _message('new', 'CSKH vừa phản hồi');
      repository.emit([reply]);
      repository.reports.add(_report(status: 'resolved'));
      await Future<void>.delayed(Duration.zero);
      repository.fetchGate!.complete([]);
      await refresh;
      expect(chat.messages!.single.id, 'new');
      expect(chat.closed, isTrue);
      expect(await chat.send('hello'), isFalse);
      expect(repository.posts, isEmpty);
    },
  );

  testWidgets('failed load can retry without opening a support ticket', (
    tester,
  ) async {
    final repository = _Repository()..failFetch = true;
    addTearDown(repository.close);
    await _mount(tester, repository);
    expect(find.text(RiskChatStrings.loadError), findsOneWidget);
    repository.failFetch = false;
    await tester.tap(find.text(RiskChatStrings.disconnected));
    // StreamSubscription.cancel() hoàn tất ở event loop thực trước khi nghe lại.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    repository.emit([_message('reply', 'Đã kết nối lại')]);
    await tester.pumpAndSettle();
    expect(repository.watchedIds, ['report-1', 'report-1']);
    expect(
      tester
          .widget<SupportChatMessages>(find.byType(SupportChatMessages))
          .messages!
          .map((m) => m.body),
      ['Đã kết nối lại'],
    );
    expect(find.text('Đã kết nối lại'), findsOneWidget);
    expect(repository.posts, isEmpty);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(882, 849),
  ]) {
    for (final keyboard in [0.0, 220.0]) {
      testWidgets('report chat fits $size with keyboard $keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        addTearDown(repository.close);
        await _mount(tester, repository, size: size, keyboard: keyboard);
        await tester.enterText(
          find.byKey(const Key('support-chat-composer')),
          'Dòng 1\nDòng 2\nDòng 3\nDòng 4',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('send-support-chat-message')).hitTestable(),
          findsOneWidget,
        );
      });
    }
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  SupportChatAttachmentDraft? attachments,
  Size size = const Size(800, 600),
  double keyboard = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: keyboard),
          textScaler: TextScaler.linear(size.width <= 390 ? 1.6 : 1),
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: RiskChatSheet(
            report: _report(),
            requesterId: 'driver',
            orderCode: 'GH-10196',
            repository: repository,
            attachmentDraft: attachments,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Repository
    implements
        ParticipantRiskReportQueryRepository,
        ParticipantRiskConversationRepository,
        ParticipantRiskLiveRepository {
  final stream = StreamController<List<CaseMessage>>.broadcast();
  final reports = StreamController<ParticipantRiskReportSummary?>.broadcast();
  final postGate = Completer<void>();
  Completer<List<CaseMessage>>? fetchGate;
  final posts = <(String, String)>[];
  final watchedIds = <String>[];
  List<CaseMessage> messages = [];
  ParticipantRiskReportSummary value = _report();
  bool failPost = false;
  bool delayPost = false;
  bool failFetch = false;

  Future<void> close() async {
    await stream.close();
    await reports.close();
  }

  void emit(List<CaseMessage> values) {
    messages = values;
    stream.add(List.of(values));
  }

  @override
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(String id) async => [
    value,
  ];
  @override
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(String id) =>
      Stream.value([value]);
  @override
  Future<ParticipantRiskReportSummary?> findActive(
    String id,
    RiskCategory category,
  ) async => value;
  @override
  Future<List<RiskReportEvent>> fetchEvents(String id) async => [];
  @override
  Future<List<CaseMessage>> fetchMessages(String id) async {
    expect(id, 'report-1');
    if (failFetch) throw StateError('network');
    if (fetchGate != null) return fetchGate!.future;
    return List.of(messages);
  }

  @override
  Stream<List<CaseMessage>> watchMessages(String id) {
    watchedIds.add(id);
    return stream.stream;
  }

  @override
  Stream<ParticipantRiskReportSummary?> watchReport(String id) =>
      reports.stream;
  @override
  Future<void> postMessage(String id, String body) async {
    posts.add((id, body));
    if (delayPost) await postGate.future;
    if (failPost) throw StateError('network');
    emit([
      ...messages,
      _message('posted-${posts.length}', body, caseId: id, sender: 'driver'),
    ]);
  }
}
