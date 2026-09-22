import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class OrderFieldLabel extends StatelessWidget {
  const OrderFieldLabel(
    this.label, {
    super.key,
    this.requiredField = true,
    this.style,
  });
  final String label;
  final bool requiredField;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: label),
        if (requiredField)
          const TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.error),
          ),
      ],
    ),
    style: style ?? AppTextStyles.labelMedium,
    semanticsLabel: requiredField ? '$label, bắt buộc' : label,
  );
}
