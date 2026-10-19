abstract final class SupportMonitoringStrings {
  static const casesTitle = 'Hồ sơ giám sát';
  static const intervention = 'Cần can thiệp';
  static const automatic = 'Nhật ký tự động';
  static const queueHint = 'Chỉ các trường hợp cần CSKH can thiệp.';
  static const logHint = 'Các lần thu hồi do hệ thống xử lý.';
  static const empty = 'Không có việc cần can thiệp';
  static const emptyHint = 'Các lần tự thu hồi nằm trong Nhật ký tự động.';
  static const automaticStatus = 'Tự động điều phối';
  static const noAcceptance = 'Không cần tiếp nhận';
  static const reclaimed = 'Đã thu hồi phân công';
  static const automaticSummary =
      'Hệ thống đã thu hồi; đơn được đưa về tìm tài xế thay thế.';
  static const automaticHelp =
      'Chỉ ghi nhận tự động. Có trao đổi mới sẽ chuyển CSKH.';
  static const verify = 'Xác minh tài xế và hàng hóa';
  static const verifySummary =
      'Liên hệ tài xế, xác minh hàng và vị trí thực tế.';
  static const verifyHelp = 'Không tự thu hồi tài xế đang giữ hàng.';
  static const participantRequest = 'Có trao đổi cần CSKH xử lý';
  static const participantHelp =
      'Đọc trao đổi mới để xác định việc cần hỗ trợ.';
  static const eventDetails = 'Chi tiết sự kiện';
  static const openOrder = 'Thông tin đơn hàng';
  static const startHandling = 'Cần can thiệp';
  static const logNotice = 'Nhật ký tự động · Không yêu cầu phản hồi';
  static const handledBySystem = 'Hệ thống xử lý';
  static const verification = [
    'Kiểm tra trạng thái đơn hiện tại, người giữ hàng và GPS hợp lệ cuối cùng.',
    'Liên hệ tài xế để xác minh vị trí, tình trạng hàng và nguyên nhân gián đoạn.',
    'Cập nhật cho khách trong đúng hội thoại; chuyển luồng sự cố nếu cần hoàn hoặc bàn giao.',
  ];
  static const completionHint =
      'Ghi kết quả xác minh và phương án đã thống nhất. '
      'Không thu hồi người đang giữ hàng chỉ vì mất GPS.';
}
