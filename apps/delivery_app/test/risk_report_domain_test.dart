import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  test('participant report payload cannot set internal severity', () {
    const submission = RiskReportSubmission(
      reportId: 'report-1',
      orderId: 'order-1',
      category: RiskCategory.cargoIssue,
      description: 'Kiện hàng bị rách trước khi giao.',
      photoPaths: [],
      messageIds: [],
    );

    expect(submission.toRpcJson(), {
      'p_report_id': 'report-1',
      'p_order_id': 'order-1',
      'p_category': 'cargo_issue',
      'p_description': 'Kiện hàng bị rách trước khi giao.',
      'p_photo_paths': <String>[],
      'p_latitude': null,
      'p_longitude': null,
      'p_location_captured_at': null,
      'p_message_ids': <String>[],
    });
    expect(submission.toRpcJson(), isNot(contains('severity')));
  });

  test('database role and intervention values parse without UI guessing', () {
    expect(RiskReporterRole.fromDatabase('driver'), RiskReporterRole.driver);
    expect(
      RiskInterventionState.fromDatabase('awaiting_triage'),
      RiskInterventionState.awaitingTriage,
    );
    expect(RiskCategory.fromDatabase('cargo_issue'), RiskCategory.cargoIssue);
  });

  test('submission result parses the report reference returned by RPC', () {
    final result = RiskReportSubmissionResult.fromJson({
      'report_id': 'report-9',
      'status': 'open',
    });

    expect(result.reportId, 'report-9');
    expect(result.status, RiskStatus.open);
  });
}
