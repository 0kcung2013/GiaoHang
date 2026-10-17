import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/vnd_input_formatter.dart';
import 'create_order_inputs.dart';

class OrderFinanceDetailsSection extends StatelessWidget {
  const OrderFinanceDetailsSection({
    super.key,
    required this.codCollectionController,
  });

  final TextEditingController codCollectionController;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      step: '03',
      icon: Icons.price_check_rounded,
      title: 'Thu tiền hộ',
      accentColor: AppColors.accent,
      subtitle: 'Tài xế ứng trước và thu lại từ người nhận',
      children: [
        _AmountField(
          controller: codCollectionController,
          semanticsLabel: 'Số tiền thu hộ COD',
          label: 'Số tiền thu hộ (COD)',
          icon: Icons.payments_rounded,
          maxAmount: 2000000,
          requiredMessage: 'Vui lòng nhập số tiền cần thu hộ.',
          errorMessage: 'Tiền thu hộ tối đa 2.000.000đ.',
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.semanticsLabel,
    required this.label,
    required this.icon,
    required this.maxAmount,
    required this.requiredMessage,
    required this.errorMessage,
    required this.textInputAction,
  });

  final TextEditingController controller;
  final String semanticsLabel;
  final String label;
  final IconData icon;
  final int maxAmount;
  final String requiredMessage;
  final String errorMessage;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticsLabel,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: textInputAction,
        inputFormatters: const [VndInputFormatter()],
        validator: (value) {
          final amount = parseVndInput(value ?? '');
          if (amount <= 0) return requiredMessage;
          return amount > maxAmount ? errorMessage : null;
        },
        style: AppTextStyles.headingSmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: '0',
          suffixText: 'đ',
          prefixIcon: Icon(icon, color: AppColors.accent),
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
    );
  }
}
