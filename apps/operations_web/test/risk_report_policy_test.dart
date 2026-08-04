import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/risk_reports/models/risk_report_policy.dart';

void main() {
  group('RiskReportPolicy', () {
    test('support cannot close a critical report', () {
      final transitions = RiskReportPolicy.allowedTransitions(
        status: RiskStatus.investigating,
        severity: RiskSeverity.critical,
        isAdmin: false,
      );

      expect(transitions, [RiskStatus.actionRequired]);
    });

    test('admin can resolve or dismiss a critical report', () {
      final transitions = RiskReportPolicy.allowedTransitions(
        status: RiskStatus.investigating,
        severity: RiskSeverity.critical,
        isAdmin: true,
      );

      expect(
        transitions,
        containsAll([RiskStatus.resolved, RiskStatus.dismissed]),
      );
    });

    test('closed reports can be reopened for investigation', () {
      expect(
        RiskReportPolicy.allowedTransitions(
          status: RiskStatus.resolved,
          severity: RiskSeverity.high,
          isAdmin: false,
        ),
        [RiskStatus.investigating],
      );
    });
  });

  test('RiskReport parses nested order data', () {
    final report = RiskReport.fromJson({
      'id': 'report-1',
      'order_id': 'order-1',
      'reported_by': 'user-1',
      'assigned_to': null,
      'category': 'suspicious_address',
      'severity': 'high',
      'status': 'open',
      'title': 'Địa chỉ nhận bất thường',
      'description': 'Địa chỉ thay đổi nhiều lần trong một giờ.',
      'resolution': null,
      'created_at': '2026-08-01T10:00:00Z',
      'updated_at': '2026-08-01T10:05:00Z',
      'orders': {
        'tracking_code': 'GH-00001',
        'status': 'delivering',
        'pickup_address': 'Điểm lấy',
        'delivery_address': 'Điểm giao',
      },
    });

    expect(report.category, RiskCategory.suspiciousAddress);
    expect(report.severity, RiskSeverity.high);
    expect(report.order.trackingCode, 'GH-00001');
  });
}
