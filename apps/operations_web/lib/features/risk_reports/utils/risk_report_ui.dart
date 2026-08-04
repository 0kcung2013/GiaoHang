import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';

class RiskReportUi {
  const RiskReportUi._();

  static String severityLabel(RiskSeverity severity) => switch (severity) {
    RiskSeverity.low => 'Thấp',
    RiskSeverity.medium => 'Trung bình',
    RiskSeverity.high => 'Cao',
    RiskSeverity.critical => 'Nghiêm trọng',
  };

  static Color severityColor(RiskSeverity severity) => switch (severity) {
    RiskSeverity.low => AppColors.info,
    RiskSeverity.medium => AppColors.warning,
    RiskSeverity.high => AppColors.accent,
    RiskSeverity.critical => AppColors.error,
  };

  static IconData severityIcon(RiskSeverity severity) => switch (severity) {
    RiskSeverity.low => Icons.info_outline_rounded,
    RiskSeverity.medium => Icons.warning_amber_rounded,
    RiskSeverity.high => Icons.priority_high_rounded,
    RiskSeverity.critical => Icons.gpp_maybe_outlined,
  };

  static String categoryLabel(RiskCategory category) => switch (category) {
    RiskCategory.deliveryDelay => 'Chậm giao hàng',
    RiskCategory.suspiciousAddress => 'Địa chỉ đáng ngờ',
    RiskCategory.repeatedCancellation => 'Hủy đơn lặp lại',
    RiskCategory.payment => 'Thanh toán',
    RiskCategory.safety => 'An toàn',
    RiskCategory.system => 'Lỗi hệ thống',
    RiskCategory.other => 'Khác',
  };

  static IconData categoryIcon(RiskCategory category) => switch (category) {
    RiskCategory.deliveryDelay => Icons.timer_outlined,
    RiskCategory.suspiciousAddress => Icons.location_off_outlined,
    RiskCategory.repeatedCancellation => Icons.event_repeat_rounded,
    RiskCategory.payment => Icons.payments_outlined,
    RiskCategory.safety => Icons.health_and_safety_outlined,
    RiskCategory.system => Icons.dns_outlined,
    RiskCategory.other => Icons.more_horiz_rounded,
  };

  static String statusLabel(RiskStatus status) => switch (status) {
    RiskStatus.open => 'Mới',
    RiskStatus.investigating => 'Đang xác minh',
    RiskStatus.actionRequired => 'Cần hành động',
    RiskStatus.resolved => 'Đã xử lý',
    RiskStatus.dismissed => 'Không rủi ro',
  };

  static Color statusColor(RiskStatus status) => switch (status) {
    RiskStatus.open => AppColors.warning,
    RiskStatus.investigating => AppColors.info,
    RiskStatus.actionRequired => AppColors.accent,
    RiskStatus.resolved => AppColors.success,
    RiskStatus.dismissed => AppColors.textSecondary,
  };

  static IconData statusIcon(RiskStatus status) => switch (status) {
    RiskStatus.open => Icons.fiber_new_rounded,
    RiskStatus.investigating => Icons.manage_search_rounded,
    RiskStatus.actionRequired => Icons.task_alt_rounded,
    RiskStatus.resolved => Icons.check_circle_outline_rounded,
    RiskStatus.dismissed => Icons.remove_circle_outline_rounded,
  };

  static String eventLabel(String eventType) => switch (eventType) {
    'created' => 'Đã tạo báo cáo',
    'assigned' => 'Đã nhận xử lý',
    'status_changed' => 'Đã đổi trạng thái',
    _ => 'Đã cập nhật báo cáo',
  };

  static String formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} · '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
