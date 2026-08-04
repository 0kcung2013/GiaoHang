import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../address_picker_strings.dart';

const addressPickerConfirmButtonKey = Key('address-picker-confirm-button');

class AddressPickerConfirmBar extends StatelessWidget {
  const AddressPickerConfirmBar({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isBusy,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadow.subtle,
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          enabled: onPressed != null,
          label: label,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: FilledButton.icon(
              key: addressPickerConfirmButtonKey,
              onPressed: isBusy ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                disabledBackgroundColor: AppColors.border,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.full,
                ),
              ),
              icon: Icon(
                isBusy ? Icons.more_horiz_rounded : Icons.check_rounded,
              ),
              label: Text(
                isBusy ? AddressPickerStrings.savingAddress : label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isBusy
                      ? AppColors.textSecondary
                      : AppColors.textOnAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
