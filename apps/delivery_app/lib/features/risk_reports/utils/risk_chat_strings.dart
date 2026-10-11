import 'package:giaohang_domain/giaohang_domain.dart';

abstract final class RiskChatStrings {
  static const subject = 'Trao đổi báo cáo';
  static const welcome = 'Trao đổi tại đây để CSKH xử lý báo cáo này.';
  static const loading = 'Đang tải hội thoại';
  static const synced = 'Đã đồng bộ hội thoại';
  static const disconnected = 'Mất kết nối · Chạm để tải lại';
  static const loadError = 'Chưa tải được hội thoại. Chạm để thử lại.';
  static const sendError = 'Chưa gửi được tin nhắn. Vui lòng thử lại.';
  static const sentRefreshError = 'Tin nhắn đã gửi. Chạm để tải lại hội thoại.';
  static const unavailable = 'Không thể truy cập báo cáo này.';
  static const tooLong = 'Tin nhắn kèm ảnh vượt quá 4.000 ký tự.';

  static String status(RiskStatus status) => switch (status) {
    RiskStatus.open => 'Chờ tiếp nhận',
    RiskStatus.investigating => 'Đang xử lý',
    RiskStatus.actionRequired => 'Cần xử lý',
    RiskStatus.waitingCustomer => 'Chờ phản hồi',
    RiskStatus.waitingAdmin => 'Chờ quản trị',
    RiskStatus.resolved => 'Đã xử lý',
    RiskStatus.dismissed => 'Đã đóng',
  };
}
