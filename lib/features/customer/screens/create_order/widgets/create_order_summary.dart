import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import '../utils/create_order_formatters.dart';

class FeeSummary extends StatelessWidget {
  const FeeSummary({super.key, required this.deliveryFee});

  final double? deliveryFee;

  @override
  Widget build(BuildContext context) {
    final hasFee = deliveryFee != null && deliveryFee! > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phí giao hàng',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasFee
                      ? 'Dựa trên phí hiện tại của luồng tạo đơn.'
                      : formatDeliveryFee(deliveryFee),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (hasFee)
            Text(
              formatDeliveryFee(deliveryFee),
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}

class OrderConfirmationSummary extends StatelessWidget {
  const OrderConfirmationSummary({
    super.key,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.recipientName,
    required this.recipientPhone,
    required this.serviceType,
    required this.paymentMethod,
    required this.note,
    required this.itemName,
    required this.itemCategory,
    required this.itemDescription,
    required this.itemImageName,
    required this.deliveryFee,
  });

  final String pickupAddress;
  final String deliveryAddress;
  final String recipientName;
  final String recipientPhone;
  final String serviceType;
  final String paymentMethod;
  final String note;
  final String itemName;
  final String itemCategory;
  final String itemDescription;
  final String? itemImageName;
  final double? deliveryFee;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryRow(
          icon: Icons.my_location_rounded,
          label: 'Lấy hàng',
          value: _valueOrPlaceholder(pickupAddress, 'Chưa nhập địa chỉ lấy'),
        ),
        _SummaryRow(
          icon: Icons.location_on_rounded,
          label: 'Giao hàng',
          value: _valueOrPlaceholder(deliveryAddress, 'Chưa nhập địa chỉ giao'),
        ),
        _SummaryRow(
          icon: Icons.person_rounded,
          label: 'Người nhận',
          value: recipientPhone.trim().isEmpty
              ? _valueOrPlaceholder(recipientName, 'Chưa nhập người nhận')
              : '${_valueOrPlaceholder(recipientName, 'Chưa nhập người nhận')} · $recipientPhone',
        ),
        _SummaryRow(
          icon: Icons.local_shipping_rounded,
          label: 'Dịch vụ',
          value: serviceTypeLabel(serviceType),
        ),
        _SummaryRow(
          icon: Icons.inventory_2_rounded,
          label: 'Hàng hoá',
          value:
              '${_valueOrPlaceholder(itemName, 'Chưa nhập hàng hoá')} · ${cargoCategoryLabel(itemCategory)}',
        ),
        _SummaryRow(
          icon: Icons.notes_rounded,
          label: 'Mô tả',
          value: _valueOrPlaceholder(itemDescription, 'Không có mô tả'),
        ),
        _SummaryRow(
          icon: Icons.image_rounded,
          label: 'Ảnh hàng',
          value: _valueOrPlaceholder(itemImageName ?? '', 'Chưa chọn ảnh'),
        ),
        _SummaryRow(
          icon: Icons.payments_rounded,
          label: 'Thanh toán',
          value: paymentMethodLabel(paymentMethod),
        ),
        _SummaryRow(
          icon: Icons.sticky_note_2_rounded,
          label: 'Ghi chú',
          value: _valueOrPlaceholder(note, 'Không có ghi chú'),
        ),
        _SummaryRow(
          icon: Icons.receipt_rounded,
          label: 'Phí',
          value: formatDeliveryFee(deliveryFee),
          isLast: true,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _valueOrPlaceholder(String value, String placeholder) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? placeholder : trimmed;
}
