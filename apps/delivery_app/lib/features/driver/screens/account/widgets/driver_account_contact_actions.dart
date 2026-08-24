import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../models/driver_account_view_data.dart';
import '../utils/driver_account_formatters.dart';
import '../utils/driver_account_strings.dart';
import 'driver_account_section_primitives.dart';

class DriverContactCard extends StatelessWidget {
  const DriverContactCard({super.key, required this.data});

  final DriverAccountViewData data;

  @override
  Widget build(BuildContext context) {
    return DriverAccountSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DriverAccountSectionHeading(
              icon: Icons.person_outline_rounded,
              title: DriverAccountStrings.contactTitle,
              color: AppColors.success,
              isProtected: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.accent,
                    size: 19,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DriverAccountStrings.readOnlyTitle,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          DriverAccountStrings.readOnlyMessage,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ContactRow(
              icon: Icons.alternate_email_rounded,
              label: DriverAccountStrings.email,
              value: driverAccountValue(data.email),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ContactRow(
              icon: Icons.phone_outlined,
              label: DriverAccountStrings.phone,
              value: driverAccountValue(data.phone),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ContactRow(
              icon: Icons.fingerprint_rounded,
              label: DriverAccountStrings.profileCode,
              value: driverProfileCode(data.driverId),
              monospace: true,
            ),
          ],
        ),
      ),
    );
  }
}

class DriverAccountLoadNotice extends StatelessWidget {
  const DriverAccountLoadNotice({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.09),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              DriverAccountStrings.loadError,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              minimumSize: const Size(48, 48),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
            ),
            child: const Text(DriverAccountStrings.retry),
          ),
        ],
      ),
    );
  }
}

class DriverAccountLogoutButton extends StatelessWidget {
  const DriverAccountLogoutButton({
    super.key,
    required this.isSigningOut,
    required this.onTap,
  });

  final bool isSigningOut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isSigningOut,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: AppRadius.full,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.full,
            splashColor: AppColors.error.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSigningOut ? Icons.sync_rounded : Icons.logout_rounded,
                    color: AppColors.error,
                    size: 21,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      isSigningOut
                          ? DriverAccountStrings.signingOut
                          : DriverAccountStrings.signOut,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style:
                    (monospace ? AppTextStyles.mono : AppTextStyles.bodyMedium)
                        .copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Tooltip(
          message: DriverAccountStrings.protectedInformation,
          child: Icon(
            Icons.lock_outline_rounded,
            color: AppColors.textMuted,
            size: 17,
          ),
        ),
      ],
    );
  }
}
