import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:test/test.dart';

void main() {
  test('classifies only the chosen subject, never infers from chat text', () {
    expect(
      SupportIssue.fromSubject('Không liên hệ được người nhận'),
      SupportIssue.recipientUnavailable,
    );
    expect(
      SupportIssue.fromSubject('  Thanh toán hoặc phí  '),
      SupportIssue.payment,
    );
    expect(
      SupportIssue.fromSubject('Khách nói tài xế giao chậm'),
      SupportIssue.other,
    );
  });
  test('recipient contact templates address each party separately', () {
    final issue = SupportIssue.recipientUnavailable;
    expect(issue.replyTemplate(forDriver: true), contains('hàng đang ở đâu'));
    expect(
      issue.replyTemplate(forDriver: false),
      contains('thời gian người nhận'),
    );
    expect(
      issue.replyTemplate(forDriver: true),
      isNot(issue.replyTemplate(forDriver: false)),
    );
  });
}
