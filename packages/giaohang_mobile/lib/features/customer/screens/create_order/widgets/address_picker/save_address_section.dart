import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../../core/models/saved_address_model.dart';
import '../../address_picker_strings.dart';
import 'address_list_item.dart';

const saveAddressSwitchKey = Key('save-address-switch');

class SaveAddressSection extends StatelessWidget {
  const SaveAddressSection({
    super.key,
    required this.enabled,
    required this.labelType,
    required this.customLabelController,
    required this.onEnabledChanged,
    required this.onLabelChanged,
    required this.onCustomLabelChanged,
    this.customLabelError,
    this.saveError,
  });

  final bool enabled;
  final SavedAddressLabelType labelType;
  final TextEditingController customLabelController;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<SavedAddressLabelType> onLabelChanged;
  final ValueChanged<String> onCustomLabelChanged;
  final String? customLabelError;
  final String? saveError;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDuration.normal,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: enabled ? AppColors.accentLight : AppColors.bgLight,
        borderRadius: AppRadius.xl,
        border: Border.all(
          color: enabled
              ? AppColors.accent.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  enabled
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                  color: AppColors.accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  AddressPickerStrings.saveForLater,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                key: saveAddressSwitchKey,
                value: enabled,
                onChanged: onEnabledChanged,
                activeThumbColor: AppColors.textOnAccent,
                activeTrackColor: AppColors.accent,
                inactiveThumbColor: AppColors.bgCard,
                inactiveTrackColor: AppColors.border,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              AddressPickerStrings.addressName,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: SavedAddressLabelType.values
                  .map((type) {
                    final selected = type == labelType;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: _label(type),
                      child: ChoiceChip(
                        selected: selected,
                        onSelected: (_) => onLabelChanged(type),
                        avatar: Icon(
                          savedAddressIcon(type),
                          size: 17,
                          color: selected
                              ? AppColors.textOnAccent
                              : AppColors.textSecondary,
                        ),
                        label: Text(_label(type)),
                        showCheckmark: false,
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.bgCard,
                        side: BorderSide(
                          color: selected ? AppColors.accent : AppColors.border,
                        ),
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: selected
                              ? AppColors.textOnAccent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.full,
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            if (labelType == SavedAddressLabelType.other) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: customLabelController,
                onChanged: onCustomLabelChanged,
                maxLength: 30,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                textInputAction: TextInputAction.done,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: _inputDecoration(
                  hint: AddressPickerStrings.customLabelHint,
                  icon: Icons.label_outline_rounded,
                  errorText: customLabelError,
                ).copyWith(counterText: ''),
              ),
            ],
            if (saveError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      saveError!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _label(SavedAddressLabelType type) => switch (type) {
    SavedAddressLabelType.home => AddressPickerStrings.home,
    SavedAddressLabelType.work => AddressPickerStrings.work,
    SavedAddressLabelType.warehouse => AddressPickerStrings.warehouse,
    SavedAddressLabelType.other => AddressPickerStrings.other,
  };
}

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
  String? errorText,
}) {
  return InputDecoration(
    hintText: hint,
    errorText: errorText,
    prefixIcon: Icon(icon, color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.bgCard,
    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
    border: _border(AppColors.border),
    enabledBorder: _border(AppColors.border),
    focusedBorder: _border(AppColors.accent, width: 1.5),
    errorBorder: _border(AppColors.error),
    focusedErrorBorder: _border(AppColors.error, width: 1.5),
    errorMaxLines: 2,
  );
}

OutlineInputBorder _border(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: AppRadius.lg,
    borderSide: BorderSide(color: color, width: width),
  );
}
