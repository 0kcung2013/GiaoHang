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

      expect(transitions, [
        RiskStatus.actionRequired,
        RiskStatus.waitingCustomer,
        RiskStatus.waitingAdmin,
      ]);
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

    test('locks manual status transitions while an order return is active', () {
      final transitions = RiskReportPolicy.allowedTransitions(
        status: RiskStatus.actionRequired,
        severity: RiskSeverity.medium,
        isAdmin: false,
        interventionState: RiskInterventionState.returnRequired,
      );

      expect(transitions, isEmpty);
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

  test('RiskReport preserves the reporter profile used by support UI', () {
    final report = RiskReport.fromJson({
      'id': 'report-profile',
      'order_id': 'order-1',
      'reported_by': 'customer-1',
      'category': 'contact_issue',
      'severity': 'medium',
      'status': 'open',
      'title': 'Không liên lạc được',
      'description': 'Khách hàng cần hỗ trợ.',
      'created_at': '2026-08-01T10:00:00Z',
      'updated_at': '2026-08-01T10:05:00Z',
      'reporter': {
        'full_name': 'Nguyễn An',
        'role': 'customer',
        'avatar_url': 'https://example.com/avatar.jpg',
        'phone': '0901234567',
        'email': 'an@example.com',
      },
      'orders': {
        'tracking_code': 'GH-00001',
        'status': 'delivering',
        'pickup_address': 'Điểm lấy',
        'delivery_address': 'Điểm giao',
      },
    });

    expect(
      report.toJson()['reporter_avatar_url'],
      'https://example.com/avatar.jpg',
    );
    expect(report.toJson()['reporter_phone'], '0901234567');
    expect(report.toJson()['reporter_email'], 'an@example.com');
  });

  test('RiskReport parses an orderless system incident', () {
    final report = RiskReport.fromJson({
      'id': 'report-system',
      'order_id': null,
      'reported_by': 'support-1',
      'scope': 'system',
      'component': 'Theo dõi đơn hàng',
      'category': 'system',
      'severity': 'critical',
      'status': 'waiting_admin',
      'title': 'Realtime gián đoạn',
      'description': 'Không nhận được cập nhật vị trí tài xế.',
      'created_at': '2026-08-12T10:00:00Z',
      'updated_at': '2026-08-12T10:05:00Z',
    });

    expect(report.isSystemIncident, isTrue);
    expect(report.orderId, isEmpty);
    expect(report.component, 'Theo dõi đơn hàng');
    expect(report.status, RiskStatus.waitingAdmin);
  });
}
