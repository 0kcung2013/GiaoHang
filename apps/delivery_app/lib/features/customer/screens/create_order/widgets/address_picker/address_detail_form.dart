import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../../core/models/saved_address_model.dart';
import '../../address_picker_strings.dart';
import '../../utils/reverse_geocode_result.dart';
import 'address_picker_states.dart';
import 'save_address_section.dart';

class AddressDetailForm extends StatelessWidget {
  const AddressDetailForm({
    super.key,
    required this.resolvedAddress,
    required this.isResolving,
    required this.resolutionError,
    required this.detailController,
    required this.noteController,
    required this.detailError,
    required this.onDetailChanged,
    required this.saveAddress,
    required this.labelType,
    required this.customLabelController,
    required this.onSaveChanged,
    required this.onLabelChanged,
    required this.onCustomLabelChanged,
    this.customLabelError,
    this.saveError,
  });

  final ReverseGeocodeResult? resolvedAddress;
  final bool isResolving;
  final String? resolutionError;
  final TextEditingController detailController;
  final TextEditingController noteController;
  final String? detailError;
  final ValueChanged<String> onDetailChanged;
  final bool saveAddress;
  final SavedAddressLabelType labelType;
  final TextEditingController customLabelController;
  final ValueChanged<bool> onSaveChanged;
  final ValueChanged<SavedAddressLabelType> onLabelChanged;
  final ValueChanged<String> onCustomLabelChanged;
  final String? customLabelError;
  final String? saveError;

  @override
  Widget build(BuildContext context) {
    final hasHouseNumber = resolvedAddress?.hasHouseNumber == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xl3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.xl,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.subtle,
            ),
            child: isResolving
                ? const AddressInlineLoading(
                    label: AddressPickerStrings.resolvingAddress,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: AppRadius.md,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.accent,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              resolvedAddress?.displayAddress ??
                                  AddressPickerStrings.unresolvedAddress,
                              style: AppTextStyles.headingSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (resolutionError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _InlineNotice(
                          message: resolutionError!,
                          color: AppColors.error,
                          icon: Icons.cloud_off_rounded,
                        ),
                      ] else if (!hasHouseNumber) ...[
                        const SizedBox(height: AppSpacing.md),
                        const _InlineNotice(
                          message: AddressPickerStrings.missingHouseNumber,
                          color: AppColors.warning,
                          icon: Icons.info_outline_rounded,
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _AddressTextField(
            controller: detailController,
            label: AddressPickerStrings.addressDetailLabel,
            hint: AddressPickerStrings.addressDetailHint,
            icon: Icons.edit_location_alt_rounded,
            errorText: detailError,
            onChanged: onDetailChanged,
            maxLength: 200,
          ),
          const SizedBox(height: AppSpacing.lg),
          _AddressTextField(
            controller: noteController,
            label: AddressPickerStrings.deliveryNoteLabel,
            hint: AddressPickerStrings.deliveryNoteHint,
            icon: Icons.notes_rounded,
            maxLines: 2,
            maxLength: 240,
          ),
          const SizedBox(height: AppSpacing.lg),
          SaveAddressSection(
            enabled: saveAddress,
            labelType: labelType,
            customLabelController: customLabelController,
            onEnabledChanged: onSaveChanged,
            onLabelChanged: onLabelChanged,
            onCustomLabelChanged: onCustomLabelChanged,
            customLabelError: customLabelError,
            saveError: saveError,
          ),
        ],
      ),
    );
  }
}

class _AddressTextField extends StatelessWidget {
  const _AddressTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.errorText,
    this.onChanged,
    this.maxLines = 1,
    required this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
          textInputAction: maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            errorMaxLines: 3,
            counterText: '',
            prefixIcon: Icon(icon, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.bgLight,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            border: _fieldBorder(AppColors.border),
            enabledBorder: _fieldBorder(AppColors.border),
            focusedBorder: _fieldBorder(AppColors.accent, width: 1.5),
            errorBorder: _fieldBorder(AppColors.error),
            focusedErrorBorder: _fieldBorder(AppColors.error, width: 1.5),
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: AppRadius.lg,
    borderSide: BorderSide(color: color, width: width),
  );
}
