import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/models/support_chat_category.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support/screens/support_home_screen.dart';

class ChatCategoryRepository implements SupportTicketRepository {
  @override
  Future<List<SupportTicket>> fetchTickets() async => [
    for (final row in [
      {'id': 'general', 'subject': 'Hỏi về tài khoản'},
      {
        'id': 'order',
        'subject': 'Hỏi về giao hàng',
        'order_id': 'order-1',
        'tracking_code': 'GH-123',
      },
      {
        'id': 'closed',
        'subject': 'Hỏi về đơn đã xong',
        'order_id': 'order-2',
        'status': 'resolved',
      },
      {
        'id': 'monitor',
        'subject': 'Giám sát: cần xác minh hành trình',
        'order_id': 'order-3',
      },
    ])
      SupportTicket.fromJson({
        'requester_id': 'customer',
        'status': 'open',
        ...row,
      }),
  ];
  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {}
  @override
  Future<void> updateStatus(
    String ticketId,
    SupportTicketStatus status,
  ) async {}
}

void main() {
  test('classification uses order link, excludes monitoring', () {
    for (final orderId in [null, '', '  ', 'order-id']) {
      final ticket = SupportTicket.fromJson({'order_id': orderId});
      expect(SupportChatCategory.order.includes(ticket), orderId == 'order-id');
      expect(
        SupportChatCategory.general.includes(ticket),
        orderId != 'order-id',
      );
    }
    final monitoring = SupportTicket.fromJson({'subject': 'Giám sát: sự việc'});
    expect(
      SupportChatCategory.values.any((c) => c.includes(monitoring)),
      isFalse,
    );
  });

  for (final size in [const Size(1280, 850), const Size(375, 568)]) {
    testWidgets(
      'separate conversations, counters, search and statuses at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width < 600 ? 1.6 : 1),
              ),
              child: child!,
            ),
            home: SupportHomeScreen(
              repository: ChatCategoryRepository(),
              currentUserId: 'support',
            ),
          ),
        );
        await tester.pumpAndSettle();
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
        expect(find.text('Cần xử lý · 1'), findsOneWidget);
        expect(find.text('Đã xong · 0'), findsOneWidget);
        Future<void> tap(Key key) async {
          final scrollable = find
              .descendant(
                of: find.byKey(const Key('support-ticket-scroll-view')),
                matching: find.byType(Scrollable),
              )
              .first;
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(key),
            100,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(key));
          await tester.pumpAndSettle();
        }

        await tap(const Key('support-chat-order'));
        expect(find.text('Đã xong · 1'), findsOneWidget);
        expect(find.text('Hỏi về tài khoản'), findsNothing);
        await tester.ensureVisible(
          find.byKey(const Key('support-ticket-search')),
        );
        await tester.enterText(
          find.byKey(const Key('support-ticket-search')),
          'GH-123',
        );
        await tester.pumpAndSettle();
        if (size.width >= 600) {
          expect(find.text('1 hồ sơ phù hợp'), findsOneWidget);
        }
        await tap(const Key('support-chat-general'));
        if (size.width >= 600) {
          expect(find.text('0 hồ sơ phù hợp'), findsOneWidget);
        }
        await tap(const Key('support-chat-order'));
        await tester.ensureVisible(
          find.byKey(const Key('support-ticket-search')),
        );
        await tester.enterText(
          find.byKey(const Key('support-ticket-search')),
          '',
        );
        await tap(const Key('support-queue-finished'));
        await tester.scrollUntilVisible(
          find.text('Hỏi về đơn đã xong'),
          180,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('support-ticket-scroll-view')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Hỏi về đơn đã xong'), findsOneWidget);
        expect(find.text('Giám sát: cần xác minh hành trình'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
