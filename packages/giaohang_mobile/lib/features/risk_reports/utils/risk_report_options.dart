import 'package:giaohang_domain/giaohang_domain.dart';

import 'risk_report_strings.dart';

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

const _driverPickup = RiskReportOption(
  category: RiskCategory.contactIssue,
  label: RiskReportStrings.pickupUnavailable,
  description: RiskReportStrings.pickupUnavailableHint,
);
const _driverDelivery = RiskReportOption(
  category: RiskCategory.contactIssue,
  label: RiskReportStrings.deliveryUnavailable,
  description: RiskReportStrings.deliveryUnavailableHint,
);
const _driverCargo = RiskReportOption(
  category: RiskCategory.cargoIssue,
  label: RiskReportStrings.cargoMismatch,
  description: RiskReportStrings.cargoMismatchHint,
);
const _driverOther = RiskReportOption(
  category: RiskCategory.other,
  label: RiskReportStrings.otherIncident,
  description: RiskReportStrings.otherIncidentHint,
);

List<RiskReportOption> riskOptionsFor(
  RiskReporterRole role, {
  String orderStatus = 'assigned',
  bool hasPickedUp = false,
}) {
  return switch (role) {
    RiskReporterRole.customer => const [
      _deliveryDelay,
      _contactIssue,
      _cargoIssue,
      _payment,
      _safety,
      _other,
    ],
    RiskReporterRole.driver =>
      hasPickedUp ||
              const [
                'delivering',
                'delivered',
                'return_approved',
                'returning',
                'returned',
              ].contains(orderStatus)
          ? const [_driverDelivery, _driverOther]
          : const [_driverCargo, _driverPickup, _driverOther],
    _ => const [],
  };
}

RiskReportOption? riskOptionFor(
  RiskReporterRole role,
  RiskCategory? category, {
  String orderStatus = 'assigned',
  bool hasPickedUp = false,
}) {
  if (category == null) return null;
  for (final option in riskOptionsFor(
    role,
    orderStatus: orderStatus,
    hasPickedUp: hasPickedUp,
  )) {
    if (option.category == category) return option;
  }
  return null;
}
