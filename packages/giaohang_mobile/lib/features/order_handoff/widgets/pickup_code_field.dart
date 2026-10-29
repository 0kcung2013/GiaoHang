import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../pickup_handoff_strings.dart';

class PickupCodeField extends StatelessWidget {
  const PickupCodeField({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(PickupHandoffStrings.driverNotice, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('pickup-code-input'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: AppTextStyles.headingLarge.copyWith(letterSpacing: 12),
          decoration: InputDecoration(
            labelText: PickupHandoffStrings.codeLabel,
            labelStyle: AppTextStyles.bodyMedium,
            filled: true,
            fillColor: AppColors.bgLight,
            counterText: '',
            border: const OutlineInputBorder(
              borderRadius: AppRadius.md,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.md,
              borderSide: BorderSide(color: AppColors.borderFocus, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
