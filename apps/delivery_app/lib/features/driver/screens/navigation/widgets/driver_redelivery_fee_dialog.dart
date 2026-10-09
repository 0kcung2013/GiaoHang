import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/driver_recipient_wait_strings.dart';

Future<bool?> showDriverRedeliveryFeeDialog(
  BuildContext context, {
  required String deliveryAddress,
}) => showDialog<bool>(
  context: context,
  builder: (_) => DriverRedeliveryFeeDialog(deliveryAddress: deliveryAddress),
);

/// Hiển thị điều kiện phí. Không tự thu phí hoặc đổi trạng thái đơn.
class DriverRedeliveryFeeDialog extends StatelessWidget {
  const DriverRedeliveryFeeDialog({super.key, required this.deliveryAddress});
  final String deliveryAddress;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl2),
    insetPadding: const EdgeInsets.all(AppSpacing.xl),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DriverRecipientWaitStrings.feeTitle,
              style: AppTextStyles.headingLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              DriverRecipientWaitStrings.rate,
              style: AppTextStyles.displayLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              DriverRecipientWaitStrings.payer,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              DriverRecipientWaitStrings.origin,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              DriverRecipientWaitStrings.destination,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(deliveryAddress, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            Text(
              DriverRecipientWaitStrings.formula,
              style: AppTextStyles.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              DriverRecipientWaitStrings.feeHint,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.textOnAccent,
                  backgroundColor: AppColors.accent,
                  textStyle: AppTextStyles.labelLarge,
                  minimumSize: const Size(48, 48),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(DriverRecipientWaitStrings.report),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: AppTextStyles.labelMedium,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text(DriverRecipientWaitStrings.close),
            ),
          ],
        ),
      ),
    ),
  );
}
