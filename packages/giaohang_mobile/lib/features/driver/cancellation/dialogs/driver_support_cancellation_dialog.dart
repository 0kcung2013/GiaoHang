import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../driver_cancellation_strings.dart';

Future<void> showDriverSupportCancellationDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const DriverSupportCancellationDialog(),
    );

class DriverSupportCancellationDialog extends StatelessWidget {
  const DriverSupportCancellationDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(AppSpacing.lg),
    child: SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.accent, size: 40),
            const SizedBox(height: AppSpacing.lg),
            Text(
              DriverCancellationStrings.supportCancelledTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              DriverCancellationStrings.supportCancelledDescription,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl2),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                textStyle: AppTextStyles.labelLarge,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
              child: const Text(DriverCancellationStrings.understood),
            ),
          ],
        ),
      ),
    ),
  );
}
