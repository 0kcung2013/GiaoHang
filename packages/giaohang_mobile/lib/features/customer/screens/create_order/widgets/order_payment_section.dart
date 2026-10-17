import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_finance.dart';
import '../../../../../core/utils/vnd_input_formatter.dart';
import 'create_order_inputs.dart';

class OrderPaymentSection extends StatelessWidget {
  const OrderPaymentSection({
    super.key,
    required this.goodsValueController,
    required this.codCollectionController,
    required this.deliveryFeePayer,
    required this.onDeliveryFeePayerChanged,
  });

  final TextEditingController goodsValueController;
  final TextEditingController codCollectionController;
  final DeliveryFeePayer deliveryFeePayer;
  final ValueChanged<DeliveryFeePayer> onDeliveryFeePayerChanged;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      step: '04',
      icon: Icons.payments_outlined,
      title: 'Thanh toán',
      accentColor: AppColors.accent,
      subtitle: 'Tách riêng phí giao và tiền thu hộ',
      children: [
        Semantics(
          textField: true,
          label: 'Giá kiện hàng',
          child: TextFormField(
            controller: goodsValueController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: const [VndInputFormatter()],
            validator: (value) {
              final amount = parseVndInput(value ?? '');
              if (amount < 0) {
                return 'Nhập giá trị hàng hợp lệ.';
              }
              if (amount > 100000000) {
                return 'Giá kiện hàng tối đa 100.000.000đ.';
              }
              return null;
            },
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              labelText: 'Giá kiện hàng',
              hintText: '0',
              suffixText: 'đ',
              prefixIcon: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.accent,
              ),
              filled: true,
              fillColor: AppColors.bgLight,
              border: const OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          textField: true,
          label: 'Số tiền thu hộ COD',
          child: TextFormField(
            controller: codCollectionController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: const [VndInputFormatter()],
            validator: (value) {
              final amount = parseVndInput(value ?? '');
              if (amount < 0 || amount > 10000000) {
                return 'Tiền thu hộ từ 0đ đến 10.000.000đ.';
              }
              return null;
            },
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            decoration: const InputDecoration(
              labelText: 'Số tiền thu hộ COD',
              hintText: '0',
              suffixText: 'đ',
              prefixIcon: Icon(Icons.payments_rounded, color: AppColors.accent),
              filled: true,
              fillColor: AppColors.bgLight,
              border: OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Người thanh toán phí giao hàng',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _PaymentModeCard(
                label: 'Thanh toán qua VNPAY',
                icon: Icons.account_balance_rounded,
                color: AppColors.success,
                selected: deliveryFeePayer == DeliveryFeePayer.sender,
                onTap: () => onDeliveryFeePayerChanged(DeliveryFeePayer.sender),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PaymentModeCard(
                label: 'Thanh toán khi nhận hàng',
                icon: Icons.payments_rounded,
                color: AppColors.accent,
                selected: deliveryFeePayer == DeliveryFeePayer.recipient,
                onTap: () =>
                    onDeliveryFeePayerChanged(DeliveryFeePayer.recipient),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentModeCard extends StatelessWidget {
  const _PaymentModeCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? color.withValues(alpha: 0.1) : AppColors.bgLight,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected ? color : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
