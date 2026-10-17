import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/widgets/stored_media_image.dart';

import '../models/driver_account_view_data.dart';
import '../utils/driver_account_strings.dart';

class DriverAccountProfileHero extends StatelessWidget {
  const DriverAccountProfileHero({
    super.key,
    required this.data,
    this.isLoading = false,
    this.hasError = false,
  });

  final DriverAccountViewData data;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final badge = _ApprovalBadgeData.from(data.approvalStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProfileAvatar(data: data),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (isLoading || hasError)
                      Text(
                        isLoading
                            ? DriverAccountStrings.loadingProfile
                            : DriverAccountStrings.loadError,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textOnDark,
                        ),
                      )
                    else
                      _ApprovalBadge(data: badge),
                  ],
                ),
              ),
            ],
          ),
          if (!isLoading && !hasError) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(color: AppColors.bgCard.withValues(alpha: 0.16), height: 1),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xl2,
              runSpacing: AppSpacing.sm,
              children: [
                _Fact(
                  icon: Icons.local_shipping_outlined,
                  label:
                      '${data.totalDeliveries} ${DriverAccountStrings.deliveries}',
                ),
                _Fact(
                  icon: data.isAvailable
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  label: data.isAvailable
                      ? DriverAccountStrings.availabilityEnabled
                      : DriverAccountStrings.availabilityDisabled,
                  color: data.isAvailable
                      ? AppColors.success
                      : AppColors.textOnDark,
                ),
              ],
            ),
          ],
          if (isLoading) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.full,
              child: const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0x24FFFFFF),
                color: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.data});

  final DriverAccountViewData data;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        data.initials,
        style: AppTextStyles.headingLarge.copyWith(
          color: AppColors.textOnAccent,
        ),
      ),
    );

    return Semantics(
      image: true,
      label: 'Ảnh đại diện của ${data.name}',
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.bgDarkCard,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: ColoredBox(
            color: AppColors.bgDarkCard,
            child: data.avatarUrl == null
                ? fallback
                : StoredMediaImage(
                    storedValue: data.avatarUrl,
                    fit: BoxFit.cover,
                    fallback: fallback,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.data});

  final _ApprovalBadgeData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.16),
        borderRadius: AppRadius.full,
        border: Border.all(color: data.color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, color: data.color, size: 14),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: data.color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.textOnDark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: foreground, size: 17),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(color: foreground),
          ),
        ),
      ],
    );
  }
}

class _ApprovalBadgeData {
  const _ApprovalBadgeData(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  factory _ApprovalBadgeData.from(String status) {
    return switch (status) {
      'approved' => const _ApprovalBadgeData(
        DriverAccountStrings.verified,
        Icons.verified_rounded,
        AppColors.success,
      ),
      'rejected' => const _ApprovalBadgeData(
        DriverAccountStrings.rejected,
        Icons.info_outline_rounded,
        AppColors.error,
      ),
      _ => const _ApprovalBadgeData(
        DriverAccountStrings.pending,
        Icons.schedule_rounded,
        AppColors.warning,
      ),
    };
  }
}
