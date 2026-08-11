import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/models/risk_message_evidence.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_message_evidence_section.dart';

void main() {
  testWidgets('shows retained evidence and attaches selected order messages', (
    tester,
  ) async {
    List<String>? attachedIds;
    final evidence = RiskMessageEvidence(
      id: 'evidence-1',
      riskReportId: 'risk-1',
      sourceMessageId: null,
      orderId: 'order-1',
      senderId: 'driver-1',
      body: 'Bằng chứng đã lưu.',
      sentAt: DateTime(2026, 8, 8, 9),
      isQuickReply: true,
      addedBy: 'staff-1',
      createdAt: DateTime(2026, 8, 8, 10),
    );
    final candidate = RiskOrderMessage(
      id: 'message-2',
      senderId: 'customer-1',
      body: 'Tin nhắn cần gắn.',
      sentAt: DateTime(2026, 8, 8, 9, 30),
      isQuickReply: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskMessageEvidenceSection(
            evidence: [evidence],
            availableMessages: [candidate],
            loading: false,
            attaching: false,
            onAttach: (ids) async => attachedIds = ids,
          ),
        ),
      ),
    );

    expect(find.text('Bằng chứng đã lưu.'), findsOneWidget);
    expect(find.text('Tin nguồn đã hết hạn'), findsOneWidget);

    await tester.tap(find.text('Gắn tin nhắn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tin nhắn cần gắn.'));
    await tester.pump();
    await tester.tap(find.text('Gắn 1 tin nhắn'));
    await tester.pumpAndSettle();

    expect(attachedIds, ['message-2']);
  });
}
