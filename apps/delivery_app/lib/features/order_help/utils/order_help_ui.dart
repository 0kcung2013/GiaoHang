import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

abstract final class OrderHelpUi {
  static String supportStatusLabel(SupportTicketStatus status) =>
      switch (status) {
        SupportTicketStatus.open => 'Chờ tiếp nhận',
        SupportTicketStatus.inProgress => 'Đang xử lý',
        SupportTicketStatus.waitingCustomer => 'Chờ bạn phản hồi',
        SupportTicketStatus.waitingAdmin => 'Đang chuyển Admin',
        SupportTicketStatus.resolved => 'Đã giải quyết',
        SupportTicketStatus.closed => 'Đã đóng',
      };

  static String riskStatusLabel(RiskStatus status) => switch (status) {
    RiskStatus.open => 'Chờ tiếp nhận',
    RiskStatus.investigating => 'Đang xác minh',
    RiskStatus.actionRequired => 'Cần hành động',
    RiskStatus.waitingCustomer => 'Chờ bạn phản hồi',
    RiskStatus.waitingAdmin => 'Đang chuyển Admin',
    RiskStatus.resolved => 'Đã giải quyết',
    RiskStatus.dismissed => 'Không xác định rủi ro',
  };

  static Color supportStatusColor(SupportTicketStatus status) =>
      switch (status) {
        SupportTicketStatus.open => AppColors.warning,
        SupportTicketStatus.inProgress => AppColors.info,
        SupportTicketStatus.waitingCustomer => AppColors.warning,
        SupportTicketStatus.waitingAdmin => AppColors.error,
        SupportTicketStatus.resolved => AppColors.success,
        SupportTicketStatus.closed => AppColors.textSecondary,
      };

  static Color riskStatusColor(RiskStatus status) => switch (status) {
    RiskStatus.open => AppColors.warning,
    RiskStatus.investigating => AppColors.info,
    RiskStatus.actionRequired => AppColors.accent,
    RiskStatus.waitingCustomer => AppColors.warning,
    RiskStatus.waitingAdmin => AppColors.error,
    RiskStatus.resolved => AppColors.success,
    RiskStatus.dismissed => AppColors.textSecondary,
  };

  static IconData supportStatusIcon(SupportTicketStatus status) =>
      switch (status) {
        SupportTicketStatus.open => Icons.schedule_rounded,
        SupportTicketStatus.inProgress => Icons.support_agent_rounded,
        SupportTicketStatus.waitingCustomer => Icons.forum_outlined,
        SupportTicketStatus.waitingAdmin => Icons.admin_panel_settings_outlined,
        SupportTicketStatus.resolved => Icons.check_circle_outline_rounded,
        SupportTicketStatus.closed => Icons.archive_outlined,
      };

  static IconData riskStatusIcon(RiskStatus status) => switch (status) {
    RiskStatus.open => Icons.schedule_rounded,
    RiskStatus.investigating => Icons.manage_search_rounded,
    RiskStatus.actionRequired => Icons.priority_high_rounded,
    RiskStatus.waitingCustomer => Icons.forum_outlined,
    RiskStatus.waitingAdmin => Icons.admin_panel_settings_outlined,
    RiskStatus.resolved => Icons.check_circle_outline_rounded,
    RiskStatus.dismissed => Icons.remove_circle_outline_rounded,
  };

  static String dateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    final vietnam = VietnamTime.toWallClock(value);
    return '${two(vietnam.day)}/${two(vietnam.month)}/${vietnam.year} · '
        '${two(vietnam.hour)}:${two(vietnam.minute)}';
  }
}
