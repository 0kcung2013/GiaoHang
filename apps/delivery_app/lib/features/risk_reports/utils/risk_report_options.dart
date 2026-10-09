import 'package:giaohang_domain/giaohang_domain.dart';

class RiskReportOption {
  const RiskReportOption({
    required this.category,
    required this.label,
    required this.description,
  });

  final RiskCategory category;
  final String label;
  final String description;
}

const _deliveryDelay = RiskReportOption(
  category: RiskCategory.deliveryDelay,
  label: 'Giao hàng chậm',
  description: 'Thời gian giao lâu hơn dự kiến.',
);
const _suspiciousAddress = RiskReportOption(
  category: RiskCategory.suspiciousAddress,
  label: 'Sai / không tìm được địa chỉ',
  description: 'Địa chỉ sai, không tiếp cận được hoặc có dấu hiệu bất thường.',
);
const _contactIssue = RiskReportOption(
  category: RiskCategory.contactIssue,
  label: 'Không thể liên lạc',
  description: 'Không gọi hoặc nhắn tin được cho bên còn lại.',
);
const _cargoIssue = RiskReportOption(
  category: RiskCategory.cargoIssue,
  label: 'Vấn đề hàng hóa',
  description: 'Hàng bị rách, hỏng, sai hoặc có dấu hiệu bất thường.',
);
const _payment = RiskReportOption(
  category: RiskCategory.payment,
  label: 'Vấn đề thanh toán',
  description: 'Khoản thu, phí hoặc phương thức thanh toán chưa đúng.',
);
const _safety = RiskReportOption(
  category: RiskCategory.safety,
  label: 'Vấn đề an toàn',
  description: 'Có nguy cơ ảnh hưởng đến người hoặc tài sản.',
);
const _other = RiskReportOption(
  category: RiskCategory.other,
  label: 'Vấn đề khác',
  description: 'Sự cố không nằm trong các lựa chọn trên.',
);

const _driverContact = RiskReportOption(
  category: RiskCategory.contactIssue,
  label: 'Không liên lạc / chưa gặp được',
  description: 'Người gửi hoặc người nhận không phản hồi, chưa ra bàn giao.',
);
const _driverSafety = RiskReportOption(
  category: RiskCategory.safety,
  label: 'Tai nạn / mất an toàn',
  description: 'Tai nạn, đe dọa hoặc nguy cơ với người và hàng hóa.',
);

List<RiskReportOption> riskOptionsFor(RiskReporterRole role) {
  return switch (role) {
    RiskReporterRole.customer => const [
      _deliveryDelay,
      _contactIssue,
      _cargoIssue,
      _payment,
      _safety,
      _other,
    ],
    RiskReporterRole.driver => const [
      _driverSafety,
      _suspiciousAddress,
      _driverContact,
      _cargoIssue,
      _payment,
      _other,
    ],
    _ => const [],
  };
}

RiskReportOption? riskOptionFor(RiskReporterRole role, RiskCategory? category) {
  if (category == null) return null;
  for (final option in riskOptionsFor(role)) {
    if (option.category == category) return option;
  }
  return null;
}
