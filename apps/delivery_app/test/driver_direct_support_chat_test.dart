import 'dart:async';
import 'dart:convert';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_help_actions.dart';
import 'package:delivery_app/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:delivery_app/features/order_help/controllers/support_chat_attachment_draft.dart';
import 'package:delivery_app/features/order_help/widgets/support_chat/support_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
  );
  const uri = 'r2://media/users/driver/order-cargo/order/support-chat/one.jpg';
  SupportChatAttachmentDraft images({
    bool fail = false,
    VoidCallback? onUpload,
  }) => SupportChatAttachmentDraft(
    contextId: 'order',
    pickImages: () async => [XFile.fromData(png, name: 'cargo.png')],
    prepareImage: (bytes) async => bytes,
    uploadImage: (bytes, order) async {
      onUpload?.call();
      if (fail) throw const R2MediaException('Upload failed');
      return uri;
    },
  );

  testWidgets('pick, preview, remove and send an image without text', (
    tester,
  ) async {
    final repository = _Repository();
    addTearDown(repository.close);
    final draft = images();
    await _mount(
      tester,
      repository,
      initial: repository.ticket,
      attachments: draft,
    );
    await tester.tap(find.byKey(const Key('attach-support-chat-image')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('remove-support-chat-image-0')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('remove-support-chat-image-0')));
    await tester.pumpAndSettle();
    expect(draft.images, isEmpty);
    await tester.tap(find.byKey(const Key('attach-support-chat-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pumpAndSettle();
    expect(CaseMessageContent.decode(repository.posted.single).images, [uri]);
    expect(draft.images, isEmpty);
    expect(
      tester.widget<ChatMessageBody>(find.byType(ChatMessageBody)).images,
      [uri],
    );
    expect(find.textContaining('r2://'), findsNothing);
  });

  testWidgets(
    'failed upload retains text and image and does not send a message',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      final draft = images(fail: true);
      await _mount(
        tester,
        repository,
        initial: repository.ticket,
        attachments: draft,
      );
      await tester.tap(find.byKey(const Key('attach-support-chat-image')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'Hàng bị móp',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pumpAndSettle();
      expect(repository.posted, isEmpty);
      expect(draft.images, hasLength(1));
      expect(find.text('Hàng bị móp'), findsOneWidget);
      expect(find.textContaining('Chưa tải được ảnh'), findsOneWidget);
    },
  );

  testWidgets('first message creates ticket with images once', (tester) async {
    final repository = _Repository();
    addTearDown(repository.close);
    await _mount(tester, repository, attachments: images());
    await tester.tap(find.byKey(const Key('attach-support-chat-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pumpAndSettle();
    expect(repository.created, hasLength(1));
    expect(repository.posted, isEmpty);
    expect(
      CaseMessageContent.decode(repository.created.single.message).images,
      [uri],
    );
  });

  testWidgets('message retry keeps attachment and does not upload it twice', (
    tester,
  ) async {
    final repository = _Repository()
      ..delayPost = true
      ..failPost = true;
    addTearDown(repository.close);
    var uploads = 0;
    final draft = images(onUpload: () => uploads++);
    await _mount(
      tester,
      repository,
      initial: repository.ticket,
      attachments: draft,
    );
    await tester.tap(find.byKey(const Key('attach-support-chat-image')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('support-chat-composer')),
      'Hàng bị móp',
    );
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pump();
    repository.postGate.complete();
    await tester.pumpAndSettle();
    expect(draft.images, hasLength(1));
    expect(find.text('Hàng bị móp'), findsOneWidget);
    repository
      ..delayPost = false
      ..failPost = false;
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pumpAndSettle();
    expect(uploads, 1);
    expect(repository.posted, hasLength(2));
    expect(repository.posted[0], repository.posted[1]);
    expect(draft.images, isEmpty);
  });

  testWidgets('Realtime confirmed images are not restored after HTTP failure', (
    tester,
  ) async {
    final repository = _Repository()
      ..delayPost = true
      ..failPost = true;
    addTearDown(repository.close);
    final draft = images();
    await _mount(
      tester,
      repository,
      initial: repository.ticket,
      attachments: draft,
    );
    await tester.tap(find.byKey(const Key('attach-support-chat-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pump();
    repository.emit(repository.posted.single);
    await tester.pump();
    repository.postGate.complete();
    await tester.pumpAndSettle();
    expect(draft.images, isEmpty);
    expect(repository.posted, hasLength(1));
    final field = tester.widget<TextField>(
      find.byKey(const Key('support-chat-composer')),
    );
    expect(field.controller!.text, isEmpty);
  });

  for (final size in [const Size(320, 568), const Size(882, 849)]) {
    for (final keyboard in [0.0, 220.0]) {
      testWidgets('direct chat fits $size with keyboard $keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        addTearDown(repository.close);
        final draft = images();
        await draft.pick();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(size.width < 400 ? 1.6 : 1),
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: SupportChatSheet(
                  requesterId: 'driver',
                  requesterRole: 'driver',
                  orderId: 'order',
                  orderCode: 'GH-10180',
                  subject: 'Trao đổi với CSKH',
                  priority: SupportTicketPriority.normal,
                  repository: repository,
                  attachmentDraft: draft,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const Key('support-chat-composer')),
          'Dòng 1\nDòng 2\nDòng 3\nDòng 4',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('support-chat-composer')), findsOneWidget);
        expect(
          find.byKey(const Key('send-support-chat-message')),
          findsOneWidget,
        );
      });
    }
  }

  testWidgets(
    'trip help opens chat directly and reuses the driver conversation',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      final order = OrderModel.fromJson({
        'id': 'order',
        'customer_id': 'customer',
        'driver_id': 'driver',
        'status': 'delivering',
        'tracking_code': 'GH-10180',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverHelpActions(
              order: order,
              collapsed: true,
              supportRepository: repository,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('driver-help-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver-help-support-option')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('support-chat-sheet')), findsOneWidget);
      expect(find.text('Đang xử lý'), findsOneWidget);
      expect(repository.created, isEmpty);
      expect(find.text('Không liên hệ được người nhận'), findsNothing);
    },
  );

  testWidgets('confirmed send is not restored for retry after HTTP fails', (
    tester,
  ) async {
    final repository = _Repository()
      ..delayPost = true
      ..failPost = true;
    addTearDown(repository.close);
    await _mount(tester, repository, initial: repository.ticket);
    await tester.enterText(
      find.byKey(const Key('support-chat-composer')),
      'xin chào',
    );
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pump();
    repository.emit('xin chào');
    await tester.pump();
    repository.postGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('xin chào'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('support-chat-composer')),
    );
    expect(field.controller!.text, isEmpty);
    expect(repository.posted, ['xin chào']);
  });

  testWidgets('empty driver message does not create a conversation', (
    tester,
  ) async {
    final repository = _Repository();
    addTearDown(repository.close);
    await _mount(tester, repository);
    await tester.enterText(
      find.byKey(const Key('support-chat-composer')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pumpAndSettle();
    expect(repository.created, isEmpty);
    expect(repository.posted, isEmpty);
  });

  for (final body in ['a', List.filled(5000, 'x').join()]) {
    testWidgets('first driver message accepts ${body.length} characters', (
      tester,
    ) async {
      final repository = _Repository();
      addTearDown(repository.close);
      await _mount(tester, repository);
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        body,
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pumpAndSettle();
      expect(repository.created.single.message, body);
      expect(repository.posted, isEmpty);
      expect(find.text(body), findsOneWidget);
    });
  }

  testWidgets(
    'Realtime confirmation replaces pending bubble while request is in flight',
    (tester) async {
      final repository = _Repository()..delayPost = true;
      addTearDown(repository.close);
      await _mount(tester, repository, initial: repository.ticket);
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'hàng cồng kềnh',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pump();
      repository.emit('hàng cồng kềnh');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('hàng cồng kềnh'), findsOneWidget);
      expect(find.text('Đang gửi...'), findsNothing);
      repository.postGate.complete();
      await tester.pumpAndSettle();
      expect(repository.posted, ['hàng cồng kềnh']);
      expect(find.text('hàng cồng kềnh'), findsOneWidget);

      // Hai lần gửi có chủ ý với cùng nội dung phải vẫn là hai tin khác nhau.
      repository.emit('hàng cồng kềnh');
      await tester.pumpAndSettle();
      expect(find.text('hàng cồng kềnh'), findsNWidgets(2));
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  SupportTicket? initial,
  SupportChatAttachmentDraft? attachments,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SupportChatSheet(
          requesterId: 'driver',
          requesterRole: 'driver',
          orderId: 'order',
          orderCode: 'GH-10180',
          subject: 'Trao đổi với CSKH',
          priority: SupportTicketPriority.normal,
          repository: repository,
          initialTicket: initial,
          attachmentDraft: attachments,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Repository
    implements
        ParticipantSupportTicketRepository,
        ParticipantSupportConversationRepository {
  final stream = StreamController<List<CaseMessage>>.broadcast();
  final created = <SupportTicketDraft>[];
  final posted = <String>[];
  final messages = <CaseMessage>[];
  final postGate = Completer<void>();
  bool delayPost = false;
  bool failPost = false;
  final ticket = SupportTicket(
    id: 'ticket',
    requesterId: 'driver',
    requesterRole: 'driver',
    orderId: 'order',
    subject: 'Hàng hóa có vấn đề',
    message: 'Nội dung trước',
    status: SupportTicketStatus.inProgress,
    priority: SupportTicketPriority.normal,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  void emit(String body) {
    messages.add(
      CaseMessage(
        id: 'message-${messages.length}',
        caseId: 'ticket',
        senderId: 'driver',
        senderRole: 'driver',
        visibility: CaseMessageVisibility.public,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
    stream.add(List.of(messages));
  }

  Future<void> close() => stream.close();
  @override
  Future<SupportTicket> create(SupportTicketDraft draft) async {
    created.add(draft);
    emit(
      draft.message,
    ); // Trigger server tạo tin đầu tiên, không gọi postMessage lần nữa.
    return ticket;
  }

  @override
  Future<List<SupportTicket>> fetchForOrder(String orderId) async => [ticket];
  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) =>
      const Stream.empty();
  @override
  Future<List<CaseMessage>> fetchMessages(String ticketId) async =>
      List.of(messages);
  @override
  Stream<List<CaseMessage>> watchMessages(String ticketId) => stream.stream;
  @override
  Future<void> postMessage(String ticketId, String body) async {
    posted.add(body);
    if (delayPost) {
      await postGate.future;
    } else {
      emit(body);
    }
    if (failPost) throw StateError('HTTP failed after commit');
  }
}
