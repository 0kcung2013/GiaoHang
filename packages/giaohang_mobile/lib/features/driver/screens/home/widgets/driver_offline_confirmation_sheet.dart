import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../driver_home_strings.dart';

Future<bool?> showDriverOfflineConfirmationSheet(
  BuildContext context, {
  bool hasActiveOrder = false,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.bgCard,
  constraints: const BoxConstraints(maxWidth: 560),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (_) =>
      DriverOfflineConfirmationSheet(hasActiveOrder: hasActiveOrder),
);

class DriverOfflineConfirmationSheet extends StatelessWidget {
  const DriverOfflineConfirmationSheet({
    super.key,
    this.hasActiveOrder = false,
  });

  final bool hasActiveOrder;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.lg,
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: AppColors.accent,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            DriverHomeStrings.offlineConfirmTitle,
            style: AppTextStyles.headingLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasActiveOrder
                ? DriverHomeStrings.offlineActiveOrderConfirmMessage
                : DriverHomeStrings.offlineConfirmMessage,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.all(AppSpacing.lg),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnDark,
              textStyle: AppTextStyles.labelLarge,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
            ),
            child: const Text(DriverHomeStrings.offlineConfirmAction),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.textPrimary,
              textStyle: AppTextStyles.labelLarge,
            ),
            child: const Text(DriverHomeStrings.offlineKeepAction),
          ),
        ],
      ),
    ),
  );
}
