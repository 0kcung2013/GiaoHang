/// Yêu cầu được gửi cùng mô tả báo cáo; không phải lệnh cho phép hoàn hàng.
abstract final class RiskRecipientReturnRequest {
  static const message =
      '[Yêu cầu hoàn hàng] Đã chờ đủ 10 phút tại điểm giao và không liên lạc '
      'được người nhận. Đề nghị CSKH xác minh và duyệt hoàn về điểm lấy.';

  // Nhận diện yêu cầu đã gửi từ phiên bản có vòng chờ thêm 15 phút.
  static const legacyMessage =
      '[Yêu cầu hoàn hàng] Đã chờ thêm 15 phút sau báo cáo không liên lạc '
      'được người nhận. Đề nghị CSKH cho phép hoàn hàng về điểm lấy ban đầu.';

  static const maximumDescriptionLength = 4000;
  static int get descriptionLimit =>
      maximumDescriptionLength - message.length - 2;

  static String describe(String description) =>
      '$message\n\n${description.trim()}';

  static bool isIncludedIn(String description) =>
      description.startsWith('$message\n\n');

  static bool isRequestMessage(String body) =>
      body == message || body == legacyMessage;
}
