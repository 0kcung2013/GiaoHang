import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/models/risk_message_evidence.dart';

void main() {
  test('parses a retained snapshot after its source message was deleted', () {
    final evidence = RiskMessageEvidence.fromJson({
      'id': 'evidence-1',
      'risk_report_id': 'risk-1',
      'source_message_id': null,
      'order_id': 'order-1',
      'sender_id': 'driver-1',
      'message_type': 'quick_reply',
      'body_snapshot': 'Tôi đang chờ tại cổng.',
      'sent_at_snapshot': '2026-08-08T02:30:00.000Z',
      'added_by': 'staff-1',
      'created_at': '2026-08-08T03:00:00.000Z',
    });

    expect(evidence.sourceMessageId, isNull);
    expect(evidence.body, 'Tôi đang chờ tại cổng.');
    expect(evidence.isQuickReply, isTrue);
    expect(evidence.sentAt, DateTime.utc(2026, 8, 8, 2, 30).toLocal());
  });

  test('parses an order message candidate', () {
    final message = RiskOrderMessage.fromJson({
      'id': 'message-1',
      'sender_id': 'customer-1',
      'message_type': 'text',
      'body': 'Tôi xuống ngay ạ.',
      'created_at': '2026-08-08T02:30:00.000Z',
    });

    expect(message.id, 'message-1');
    expect(message.body, 'Tôi xuống ngay ạ.');
    expect(message.isQuickReply, isFalse);
  });
}
