import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../utils/driver_account_strings.dart';

Future<bool> showDriverAccountLogoutSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DriverAccountLogoutSheet(),
  );
  return result ?? false;
}

class _DriverAccountLogoutSheet extends StatelessWidget {
  const _DriverAccountLogoutSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl2,
        AppSpacing.md,
        AppSpacing.xl2,
        AppSpacing.xl2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl2,
        boxShadow: AppShadow.elevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.full,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            DriverAccountStrings.signOutTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            DriverAccountStrings.signOutMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  label: DriverAccountStrings.cancel,
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: AppColors.bgLight,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SheetButton(
                  label: DriverAccountStrings.signOut,
                  foregroundColor: AppColors.textOnAccent,
                  backgroundColor: AppColors.error,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: backgroundColor,
        borderRadius: AppRadius.full,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge.copyWith(color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }
}
