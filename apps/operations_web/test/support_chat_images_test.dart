import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/support/widgets/support_live_messages.dart';

void main() {
  const reportedUri =
      'r2://media/users/8398b809-fb41-4381-a7a4-51cb04834d0f/'
      'order-cargo/eb7baabc-49b6-4e02-b732-44ec7f833de7/support-chat/'
      '1791432765778_3835d067-c2eb-4f1c-a724-673e6b25b0f7.jpg';
  const reportedBody = 'đơn sai kích cỡ\n\n[Ảnh đính kèm]($reportedUri)';

  test(
    'the stored message from the reported conversation decodes as an image',
    () {
      final content = CaseMessageContent.decode(reportedBody);
      expect(content.text, 'đơn sai kích cỡ');
      expect(content.images, [reportedUri]);
    },
  );

  const uri =
      'r2://media/users/driver/order-cargo/order/support-chat/image.jpg';
  for (final size in [const Size(500, 600), const Size(1200, 800)]) {
    testWidgets(
      'CSKH shows caption and images without storage paths at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SupportLiveMessages(
                currentUserId: 'support',
                scrollController: scroll,
                messages: [
                  CaseMessage(
                    id: 'message',
                    caseId: 'ticket',
                    senderId: 'driver',
                    senderRole: 'driver',
                    visibility: CaseMessageVisibility.public,
                    body: reportedBody,
                    createdAt: DateTime(2026),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('đơn sai kích cỡ'), findsOneWidget);
        expect(find.textContaining('r2://'), findsNothing);
        expect(
          tester.widget<ChatMessageBody>(find.byType(ChatMessageBody)).images,
          [reportedUri],
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'attachment opens zoomable viewer and closes back to conversation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBody(
              text: 'Ảnh hàng',
              images: const [uri],
              imageBuilder: (_, _) => const ColoredBox(color: AppColors.info),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('chat-image-0')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng ảnh'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.text('Ảnh hàng'), findsOneWidget);
    },
  );
}
