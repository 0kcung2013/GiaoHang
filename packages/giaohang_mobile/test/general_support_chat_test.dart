import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/mobile_app_role.dart';
import 'package:giaohang_mobile/features/help_center/help_center_strings.dart';
import 'package:giaohang_mobile/features/help_center/screens/general_support_chat_screen.dart';
import 'package:giaohang_mobile/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:giaohang_mobile/features/order_help/widgets/support_chat/support_chat_sheet.dart';
import 'helpers/utraffic_capture_fonts.dart';

void main() {
  const captureDir = String.fromEnvironment('HELP_CAPTURE_DIR');
  setUpAll(() async {
    if (captureDir.isNotEmpty) await prepareUtrafficCaptureFonts();
  });
  for (final role in MobileAppRole.values) {
    testWidgets('${role.name} starts ordinary chat without any order', (
      tester,
    ) async {
      final repository = _Repository();
      addTearDown(repository.close);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _mount(tester, role, repository);
      expect(find.text('Hỗ trợ chung'), findsOneWidget);
      expect(find.textContaining('Mã đơn đã được đính kèm'), findsNothing);
      final chat = tester.widget<SupportChatSheet>(
        find.byType(SupportChatSheet),
      );
      expect(chat.orderId, isNull);
      expect(find.byKey(const Key('attach-support-chat-image')), findsNothing);
      if (captureDir.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$captureDir/${role.name}-general-chat.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'Chào',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pumpAndSettle();
      expect(repository.created.single.orderId, isNull);
      expect(repository.created.single.requesterId, 'participant');
      expect(repository.created.single.message, 'Chào');
    });

    testWidgets('${role.name} general chat fits short phone with keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
              viewInsets: const EdgeInsets.only(bottom: 220),
            ),
            child: child!,
          ),
          home: GeneralSupportChatScreen(
            role: role,
            repository: repository,
            requesterId: 'participant',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'Cần hỗ trợ',
      );
      expect(
        find.byKey(const Key('send-support-chat-message')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reuses active general case and excludes foreign or order cases',
    (tester) async {
      final repository = _Repository()
        ..tickets = [
          _ticket('foreign', requester: 'other'),
          _ticket('order-case', order: 'order'),
          _ticket(
            'closed',
            status: SupportTicketStatus.closed,
            updated: DateTime(2027),
          ),
          _ticket('active'),
        ];
      addTearDown(repository.close);
      await _mount(tester, MobileAppRole.customer, repository);
      expect(
        tester
            .widget<SupportChatSheet>(find.byType(SupportChatSheet))
            .initialTicket
            ?.id,
        'active',
      );
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'Hỏi thêm',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pumpAndSettle();
      expect(repository.postedTicketId, 'active');
      expect(repository.created, isEmpty);
    },
  );

  testWidgets('load error is retried before allowing a new general case', (
    tester,
  ) async {
    final repository = _Repository()..failLoad = true;
    addTearDown(repository.close);
    await _mount(tester, MobileAppRole.driver, repository);
    expect(find.text(HelpCenterStrings.generalLoadError), findsOneWidget);
    expect(find.byType(SupportChatSheet), findsNothing);
    expect(repository.created, isEmpty);
    repository.failLoad = false;
    await tester.tap(find.text(HelpCenterStrings.retry));
    await tester.pumpAndSettle();
    expect(find.byType(SupportChatSheet), findsOneWidget);
  });

  testWidgets(
    'closed general conversation can be reopened without order context',
    (tester) async {
      final repository = _Repository()
        ..tickets = [_ticket('closed', status: SupportTicketStatus.closed)];
      addTearDown(repository.close);
      await _mount(tester, MobileAppRole.customer, repository);
      await tester.tap(find.text('Vấn đề chưa được giải quyết'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'Tôi vẫn cần kiểm tra tài khoản.',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pump();
      // Stream cancellation may complete in the real zone before reconnecting.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(repository.reopened, 'closed');
      expect(repository.created, isEmpty);
    },
  );

  testWidgets(
    'wallet context is retained in the first ticket even after editing the draft',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        MaterialApp(
          home: GeneralSupportChatScreen(
            role: MobileAppRole.customer,
            repository: repository,
            requesterId: 'participant',
            subject: 'Kiểm tra giao dịch',
            initialBody: 'Thông tin giao dịch',
            contextMarker: '[GD:customer:tx-1]',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'Cần kiểm tra lại số tiền',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pumpAndSettle();
      expect(
        repository.created.single.message,
        '[GD:customer:tx-1]\nCần kiểm tra lại số tiền',
      );
      expect(repository.created.single.orderId, isNull);
    },
  );

  testWidgets('general account chat does not reuse a financial conversation', (
    tester,
  ) async {
    final repository = _Repository()
      ..tickets = [
        _ticket('financial', message: '[GD:customer:tx-1]\nKiểm tra giao dịch'),
        _ticket('account'),
      ];
    addTearDown(repository.close);
    await _mount(tester, MobileAppRole.customer, repository);
    expect(
      tester
          .widget<SupportChatSheet>(find.byType(SupportChatSheet))
          .initialTicket
          ?.id,
      'account',
    );
  });
}

Future<void> _mount(
  WidgetTester tester,
  MobileAppRole role,
  _Repository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GeneralSupportChatScreen(
        role: role,
        repository: repository,
        requesterId: 'participant',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SupportTicket _ticket(
  String id, {
  String requester = 'participant',
  String? order,
  SupportTicketStatus status = SupportTicketStatus.open,
  DateTime? updated,
  String message = 'Cần hỗ trợ tài khoản',
}) => SupportTicket(
  id: id,
  requesterId: requester,
  orderId: order,
  subject: HelpCenterStrings.subject,
  message: message,
  status: status,
  priority: SupportTicketPriority.normal,
  createdAt: DateTime(2026),
  updatedAt: updated ?? DateTime(2026),
);

class _Repository
    implements
        ParticipantGeneralSupportTicketRepository,
        ParticipantSupportConversationRepository,
        ParticipantSupportDetailRepository,
        ParticipantSupportReopenRepository {
  final stream = StreamController<List<CaseMessage>>.broadcast();
  final created = <SupportTicketDraft>[];
  List<SupportTicket> tickets = [];
  bool failLoad = false;
  String? postedTicketId;
  String? reopened;

  Future<void> close() => stream.close();
  @override
  Future<List<SupportTicket>> fetchGeneralTickets() async {
    if (failLoad) throw StateError('offline');
    return tickets;
  }

  @override
  Future<SupportTicket> create(SupportTicketDraft draft) async {
    created.add(draft);
    return _ticket('created');
  }

  @override
  Future<List<SupportTicket>> fetchForOrder(String orderId) =>
      throw StateError('must not query orders');
  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) =>
      throw StateError('must not watch orders');
  @override
  Future<List<CaseMessage>> fetchMessages(String ticketId) async {
    return [];
  }

  @override
  Stream<List<CaseMessage>> watchMessages(String ticketId) => stream.stream;
  @override
  Future<void> postMessage(String ticketId, String body) async {
    postedTicketId = ticketId;
  }

  @override
  Stream<List<SupportTicket>> watchTicket(String ticketId) =>
      const Stream.empty();
  @override
  Future<SupportTicket> reopen(String ticketId, String reason) async {
    reopened = ticketId;
    stream.add([
      CaseMessage(
        id: 'reopened-message',
        caseId: ticketId,
        senderId: 'participant',
        senderRole: 'customer',
        visibility: CaseMessageVisibility.public,
        body: reason,
        createdAt: DateTime(2026),
      ),
    ]);
    return _ticket(ticketId);
  }
}
