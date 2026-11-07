import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

/// Đọc phí đã chốt trên đơn, không tính lại theo bảng giá hiện tại.
class CargoPricingSummary extends StatelessWidget {
  const CargoPricingSummary({super.key, required this.details, this.policy});
  final CargoDetails details;
  final BusinessSettings? policy;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${details.packageCount} kiện · Kích thước ${details.sizeGroup.label}',
        style: AppTextStyles.bodySmall,
      ),
      if (policy != null && CargoPricingPolicy.supported(policy!))
        Text(
          'Tối đa ${CargoPricingPolicy.dimensions(policy!, details.sizeGroup)} khi xếp chung',
          style: AppTextStyles.bodySmall,
        ),
      Text(
        '${details.tier?.label ?? details.sizeGroup.label} · Phụ phí hàng: ${formatVnd(details.surcharge)}',
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent),
      ),
    ],
  );
}
