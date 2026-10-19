import 'package:giaohang_domain/giaohang_domain.dart';

abstract final class SupportRiskConversionStrings {
  static const heading = 'Báo cáo sự cố';
  static const title = 'Tiêu đề';
  static const titleHint = 'Tóm tắt sự cố cần xử lý';
  static const titleError = 'Nhập tiêu đề ít nhất 3 ký tự.';
  static const description = 'Mô tả sự cố';
  static const descriptionHint =
      'Chuyện gì đã xảy ra? Có dấu hiệu, bằng chứng nào?';
  static const descriptionHelp = 'Ít nhất 10 ký tự, kèm bằng chứng nếu có.';
  static const descriptionError = 'Mô tả cần ít nhất 10 ký tự.';
  static const component = 'Khu vực gặp sự cố';
  static const componentHint = 'VD: Đăng nhập, thanh toán, theo dõi đơn';
  static const componentError = 'Nhập khu vực gặp sự cố (ít nhất 2 ký tự).';
  static const category = 'Loại sự cố';
  static const severity = 'Mức độ';
  static const cancel = 'Hủy';
  static const create = 'Tạo báo cáo';

  static const categories = {
    RiskCategory.deliveryDelay: 'Chậm giao',
    RiskCategory.suspiciousAddress: 'Địa chỉ đáng ngờ',
    RiskCategory.contactIssue: 'Liên lạc',
    RiskCategory.cargoIssue: 'Hàng hóa',
    RiskCategory.repeatedCancellation: 'Hủy lặp lại',
    RiskCategory.payment: 'Thanh toán',
    RiskCategory.safety: 'An toàn',
    RiskCategory.system: 'Hệ thống',
    RiskCategory.other: 'Khác',
  };
  static const severities = {
    RiskSeverity.low: 'Thấp',
    RiskSeverity.medium: 'Trung bình',
    RiskSeverity.high: 'Cao',
    RiskSeverity.critical: 'Nghiêm trọng',
  };
}
