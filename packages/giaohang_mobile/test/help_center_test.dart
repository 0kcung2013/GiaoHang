import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/mobile_app_role.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/features/help_center/data/help_topics.dart';
import 'package:giaohang_mobile/features/help_center/help_center_strings.dart';
import 'package:giaohang_mobile/features/help_center/screens/help_center_screen.dart';
import 'package:giaohang_mobile/features/help_center/screens/support_order_picker_screen.dart';
import 'package:giaohang_mobile/features/help_center/widgets/help_center_button.dart';
import 'package:giaohang_mobile/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:giaohang_mobile/features/order_help/widgets/support_chat/support_chat_sheet.dart';
import 'package:go_router/go_router.dart';

import 'helpers/utraffic_capture_fonts.dart';

void main() {
  const captureDir = String.fromEnvironment('HELP_CAPTURE_DIR');
  setUpAll(() async {
    if (captureDir.isNotEmpty) await prepareUtrafficCaptureFonts();
  });

  for (final role in MobileAppRole.values) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(1280, 800),
    ]) {
      testWidgets('${role.name} help answers and chat fit $size', (
        tester,
      ) async {
        _viewport(tester, size);
        var chats = 0;
        final topics = helpTopicsFor(role);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width == 320 ? 1.6 : 1),
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundary,
              child: HelpCenterScreen(role: role, onChat: () => chats++),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('help-center-chat')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('help-center-chat')));
        expect(chats, 1);
        if (captureDir.isNotEmpty && size.width == 390) {
          await _capture(tester, boundary, '$captureDir/${role.name}-help.png');
        }
        await tester.scrollUntilVisible(
          find.text(topics.first.question).hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(topics.first.question));
        await tester.pumpAndSettle();
        expect(find.text(topics.first.answer), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text(HelpCenterStrings.chat).last.hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(HelpCenterStrings.chat).last);
        expect(chats, 2);
        if (captureDir.isNotEmpty && size.width == 390) {
          await _capture(
            tester,
            boundary,
            '$captureDir/${role.name}-answer.png',
          );
        }
      });
    }
  }

  testWidgets('search filters questions and recovers from no matches', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HelpCenterScreen(role: MobileAppRole.driver, onChat: () {}),
      ),
    );
    await tester.enterText(find.byKey(const Key('help-center-search')), 'GPS');
    await tester.pumpAndSettle();
    expect(find.text(driverHelpTopics[5].question), findsOneWidget);
    expect(find.text(customerHelpTopics.first.question), findsNothing);
    await tester.enterText(
      find.byKey(const Key('help-center-search')),
      'zzzz-no-match',
    );
    await tester.pumpAndSettle();
    expect(find.text(HelpCenterStrings.noResults), findsOneWidget);
    await tester.tap(find.byTooltip(HelpCenterStrings.clearSearch));
    await tester.pumpAndSettle();
    expect(find.text(driverHelpTopics.first.question), findsOneWidget);
  });

  testWidgets('home support button opens help and Back returns home', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: HelpCenterButton()),
        ),
        GoRoute(
          path: '/help',
          builder: (_, _) =>
              const HelpCenterScreen(role: MobileAppRole.customer),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byTooltip(HelpCenterStrings.title));
    await tester.pumpAndSettle();
    expect(find.byType(HelpCenterScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HelpCenterButton), findsOneWidget);
  });

  for (final role in MobileAppRole.values) {
    testWidgets('${role.name} starts chat with selected order and requester', (
      tester,
    ) async {
      final repository = _Repository();
      await _picker(tester, role, repository);
      await tester.tap(find.text('GH-TEST'));
      await tester.pumpAndSettle();
      expect(repository.requestedOrder, 'order');
      final chat = tester.widget<SupportChatSheet>(
        find.byType(SupportChatSheet),
      );
      expect(chat.requesterId, 'participant');
      expect(chat.requesterRole, role.name);
      expect(chat.orderId, 'order');
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'Tôi cần kiểm tra đơn hàng này.',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pumpAndSettle();
      expect(repository.created.single.orderId, 'order');
      expect(repository.created.single.requesterId, 'participant');
      expect(repository.created.single.subject, HelpCenterStrings.subject);
    });
  }

  testWidgets('existing cases exclude monitoring and other requesters', (
    tester,
  ) async {
    final repository = _Repository()
      ..tickets = [
        _ticket('other', 'Không được hiện', requester: 'another-person'),
        _ticket('monitor', 'Giám sát: thu hồi phân công'),
        _ticket('existing', 'Thanh toán hoặc phí'),
      ];
    await _picker(tester, MobileAppRole.driver, repository);
    await tester.tap(find.text('GH-TEST'));
    await tester.pumpAndSettle();
    expect(find.text('Không được hiện'), findsNothing);
    expect(find.text('Giám sát: thu hồi phân công'), findsNothing);
    await tester.tap(find.text('Thanh toán hoặc phí'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SupportChatSheet>(find.byType(SupportChatSheet))
          .initialTicket
          ?.id,
      'existing',
    );
    expect(repository.created, isEmpty);
  });

  testWidgets(
    'failed conversation load permits retry without creating a ticket',
    (tester) async {
      final repository = _Repository()..fail = true;
      await _picker(tester, MobileAppRole.customer, repository);
      await tester.tap(find.text('GH-TEST'));
      await tester.pumpAndSettle();
      expect(find.text(HelpCenterStrings.conversationError), findsOneWidget);
      expect(find.byType(SupportChatSheet), findsNothing);
      expect(repository.created, isEmpty);
      repository.fail = false;
      await tester.tap(find.text('GH-TEST'));
      await tester.pumpAndSettle();
      expect(find.byType(SupportChatSheet), findsOneWidget);
    },
  );

  testWidgets('empty orders show guidance and load error can be retried', (
    tester,
  ) async {
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: SupportOrderPickerScreen(
          role: MobileAppRole.customer,
          requesterId: 'participant',
          loadOrders: (_) async {
            if (fail) throw StateError('offline');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(HelpCenterStrings.loadError), findsOneWidget);
    fail = false;
    await tester.tap(find.text(HelpCenterStrings.retry));
    await tester.pumpAndSettle();
    expect(find.textContaining(HelpCenterStrings.noOrders), findsOneWidget);
  });
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _picker(
  WidgetTester tester,
  MobileAppRole role,
  _Repository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SupportOrderPickerScreen(
        role: role,
        requesterId: 'participant',
        repository: repository,
        loadOrders: (_) async => [_order],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _order = OrderModel.fromJson({
  'id': 'order',
  'customer_id': 'participant',
  'driver_id': 'participant',
  'status': 'delivering',
  'tracking_code': 'GH-TEST',
  'pickup_address': 'Điểm lấy hàng',
  'delivery_address': 'Điểm giao hàng',
  'created_at': '2026-10-18T01:00:00Z',
  'updated_at': '2026-10-18T01:00:00Z',
});

SupportTicket _ticket(
  String id,
  String subject, {
  String requester = 'participant',
}) => SupportTicket(
  id: id,
  requesterId: requester,
  orderId: 'order',
  subject: subject,
  message: 'Nội dung hỗ trợ ban đầu.',
  status: SupportTicketStatus.open,
  priority: SupportTicketPriority.normal,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Repository implements ParticipantSupportTicketRepository {
  bool fail = false;
  String? requestedOrder;
  List<SupportTicket> tickets = [];
  final created = <SupportTicketDraft>[];
  @override
  Future<List<SupportTicket>> fetchForOrder(String orderId) async {
    requestedOrder = orderId;
    if (fail) throw StateError('offline');
    return tickets;
  }

  @override
  Future<SupportTicket> create(SupportTicketDraft draft) async {
    created.add(draft);
    return _ticket('created', draft.subject);
  }

  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) =>
      const Stream.empty();
}
