import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

abstract final class SupportTicketUi {
  static String statusLabel(SupportTicketStatus status) => switch (status) {
    SupportTicketStatus.open => 'Mới',
    SupportTicketStatus.inProgress => 'Đang xử lý',
    SupportTicketStatus.waitingCustomer => 'Chờ người dùng',
    SupportTicketStatus.waitingAdmin => 'Chờ Admin',
    SupportTicketStatus.resolved => 'Đã xử lý',
    SupportTicketStatus.closed => 'Đã đóng',
  };

  static IconData statusIcon(SupportTicketStatus status) => switch (status) {
    SupportTicketStatus.open => Icons.mark_unread_chat_alt_rounded,
    SupportTicketStatus.inProgress => Icons.pending_actions_rounded,
    SupportTicketStatus.waitingCustomer => Icons.forum_outlined,
    SupportTicketStatus.waitingAdmin => Icons.admin_panel_settings_outlined,
    SupportTicketStatus.resolved => Icons.check_circle_rounded,
    SupportTicketStatus.closed => Icons.archive_rounded,
  };

  static Color statusColor(SupportTicketStatus status) => switch (status) {
    SupportTicketStatus.open => AppColors.warning,
    SupportTicketStatus.inProgress => AppColors.info,
    SupportTicketStatus.waitingCustomer => AppColors.warning,
    SupportTicketStatus.waitingAdmin => AppColors.error,
    SupportTicketStatus.resolved => AppColors.success,
    SupportTicketStatus.closed => AppColors.textSecondary,
  };

  static String priorityLabel(SupportTicketPriority priority) =>
      switch (priority) {
        SupportTicketPriority.low => 'Thấp',
        SupportTicketPriority.normal => 'Bình thường',
        SupportTicketPriority.high => 'Cao',
      };

  static Color priorityColor(SupportTicketPriority priority) =>
      switch (priority) {
        SupportTicketPriority.low => AppColors.success,
        SupportTicketPriority.normal => AppColors.info,
        SupportTicketPriority.high => AppColors.error,
      };

  static String requesterRoleLabel(String role) => switch (role) {
    'driver' => 'Tài xế',
    _ => 'Khách hàng',
  };

  static IconData requesterRoleIcon(String role) => switch (role) {
    'driver' => Icons.local_shipping_outlined,
    _ => Icons.person_outline_rounded,
  };

  static String shortId(String value) {
    if (value.length <= 8) return value;
    return value.substring(0, 8).toUpperCase();
  }

  static String dateTimeLabel(DateTime value) {
    final local = VietnamTime.toWallClock(value);
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)} · '
        '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year}';
  }
}
