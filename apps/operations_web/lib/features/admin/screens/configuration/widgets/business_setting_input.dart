import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/settings_fields.dart';
import '../utils/settings_currency_formatter.dart';

class BusinessSettingInput extends StatelessWidget {
  const BusinessSettingInput({
    super.key,
    required this.inputKey,
    required this.field,
    required this.value,
    required this.enabled,
    required this.attempted,
    required this.onChanged,
  });
  final Key inputKey;
  final SettingsField field;
  final String value;
  final bool enabled, attempted;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(field.label, style: AppTextStyles.labelMedium),
      const SizedBox(height: AppSpacing.sm),
      Semantics(
        label: field.label,
        child: TextFormField(
          key: inputKey,
          initialValue: value,
          enabled: enabled,
          keyboardType: field.numeric
              ? TextInputType.numberWithOptions(decimal: !field.monetary)
              : field.key == 'support_email'
              ? TextInputType.emailAddress
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          inputFormatters: field.monetary
              ? const [SettingsCurrencyFormatter()]
              : null,
          autovalidateMode: attempted
              ? AutovalidateMode.always
              : AutovalidateMode.onUserInteraction,
          validator: (text) => field.validate(text ?? ''),
          onChanged: onChanged,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            errorMaxLines: 3,
            suffixText: field.unit.isEmpty ? null : field.unit,
            filled: true,
            fillColor: AppColors.bgLight,
            border: const OutlineInputBorder(borderRadius: AppRadius.md),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.md,
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),
      if (field.description != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          field.description!,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ],
  );
}
