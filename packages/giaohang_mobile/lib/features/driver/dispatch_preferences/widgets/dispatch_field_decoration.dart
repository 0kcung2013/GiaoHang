import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

InputDecoration dispatchFieldDecoration(String label, {Widget? suffixIcon}) =>
    InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.bodyMedium,
      filled: true,
      fillColor: AppColors.bgCard,
      contentPadding: const EdgeInsets.all(AppSpacing.lg),
      suffixIcon: suffixIcon,
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
        borderSide: BorderSide(color: AppColors.borderFocus, width: 2),
      ),
    );
