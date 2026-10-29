import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support/widgets/support_live_conversation.dart';
import 'package:operations_web/features/support/widgets/support_ticket_card.dart';

void main() {
  for (final viewport in [
    (size: const Size(1142, 768), scale: 1.0),
    (size: const Size(800, 568), scale: 1.6),
    (size: const Size(320, 568), scale: 1.6),
  ]) {
    testWidgets(
      'long ticket remains readable and keyboard accessible at $viewport',
      (tester) async {
        await tester.binding.setSurfaceSize(viewport.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var opened = false;
        final ticket = SupportTicket(
          id: 'ticket-long',
          requesterId: 'customer-1',
          requesterRole: 'customer',
          requesterName:
              'Nguyễn Thị Hoàng Anh — Chi nhánh Thành phố Hồ Chí Minh',
          assignedTo: 'support-1',
          assignedToName: 'Trần Thị Minh Thư — Bộ phận chăm sóc khách hàng',
          orderId: 'order-1',
          trackingCode: 'GH-20261019-001234',
          subject: 'Nhờ kiểm tra thông tin người nhận và địa chỉ giao hàng',
          message: 'Người nhận đang có mặt tại địa chỉ đã đăng ký.',
          lastMessageRole: 'customer',
          status: SupportTicketStatus.inProgress,
          priority: SupportTicketPriority.high,
          createdAt: DateTime(2026, 10, 19),
          updatedAt: DateTime(2026, 10, 19, 10, 42),
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SupportTicketCard(
                  ticket: ticket,
                  onTap: () => opened = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(ticket.subject), findsOneWidget);
        expect(find.textContaining(ticket.requesterName!), findsOneWidget);
        expect(find.text(ticket.assignedToName!), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'note mode keeps draft through resize and sends with internal visibility',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sent = <({String body, CaseMessageVisibility visibility})>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SupportLiveConversation(
              messages: const [],
              currentUserId: 'support-1',
              recipientLabel: 'Khách hàng — Nguyễn Thị Hoàng Anh',
              canReply: true,
              onSend: (body, visibility) async {
                sent.add((body: body, visibility: visibility));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const draft = 'Đã liên hệ tài xế, đang chờ xác nhận từ người nhận.';
      await tester.enterText(find.byType(TextField), draft);
      await tester.tap(find.text('Ghi chú nội bộ'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      await tester.binding.setSurfaceSize(const Size(375, 360));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        draft,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Lưu ghi chú nội bộ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Lưu ghi chú nội bộ'));
      await tester.pumpAndSettle();
      expect(sent.single.body, draft);
      expect(sent.single.visibility, CaseMessageVisibility.internal);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
