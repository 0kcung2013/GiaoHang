import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/return_navigation_strings.dart';

Future<bool> showCancelReturnSheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ReturnNavigationStrings.cancelReturn,
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                ReturnNavigationStrings.cancelReturnMessage,
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xl2),
              FilledButton(
                key: const Key('return-confirm-redelivery'),
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  textStyle: AppTextStyles.labelLarge,
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  minimumSize: const Size(0, 52),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lg,
                  ),
                ),
                child: const Text(ReturnNavigationStrings.confirmRedelivery),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  textStyle: AppTextStyles.labelMedium,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text(ReturnNavigationStrings.continueReturn),
              ),
            ],
          ),
        ),
      ),
    ) ??
    false;
