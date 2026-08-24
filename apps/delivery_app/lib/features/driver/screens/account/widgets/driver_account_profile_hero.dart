import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../models/driver_account_view_data.dart';
import '../utils/driver_account_strings.dart';

class DriverAccountProfileHero extends StatelessWidget {
  const DriverAccountProfileHero({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  final DriverAccountViewData data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final badge = _ApprovalBadgeData.from(data.approvalStatus);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.bgDark],
          ),
          borderRadius: AppRadius.xl2,
          boxShadow: AppShadow.elevated,
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -38,
              top: -54,
              child: ExcludeSemantics(child: _DecorativeCircle(size: 132)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverAccountStrings.profileEyebrow,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.64),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                            style: AppTextStyles.headingLarge.copyWith(
                              color: AppColors.textOnDark,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            data.email.isEmpty
                                ? DriverAccountStrings.notUpdated
                                : data.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textOnDark.withValues(
                                alpha: 0.68,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ApprovalBadge(data: badge),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.08),
                    borderRadius: AppRadius.lg,
                    border: Border.all(
                      color: AppColors.bgCard.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _Metric(
                        value: data.totalDeliveries.toString(),
                        label: DriverAccountStrings.deliveries,
                      ),
                      const _MetricDivider(),
                      _Metric(
                        value: data.isAvailable
                            ? DriverAccountStrings.enabled
                            : DriverAccountStrings.disabled,
                        label: DriverAccountStrings.availability,
                        valueColor: data.isAvailable
                            ? AppColors.success
                            : AppColors.textOnDark,
                      ),
                    ],
                  ),
                ),
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
          ],
        ),
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
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bgCard.withValues(alpha: 0.72)),
        ),
        child: ClipOval(
          child: ColoredBox(
            color: AppColors.accent,
            child: data.avatarUrl == null
                ? fallback
                : Image.network(
                    data.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
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

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingSmall.copyWith(
              color: valueColor ?? AppColors.textOnDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.bgCard.withValues(alpha: 0.12),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: 0.08),
      ),
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
