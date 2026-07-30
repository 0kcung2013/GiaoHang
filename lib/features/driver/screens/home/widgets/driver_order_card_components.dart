import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../utils/driver_home_formatters.dart';

class DriverContinueDeliveryButton extends StatelessWidget {
  const DriverContinueDeliveryButton({
    super.key,
    required this.status,
    required this.onTap,
  });

  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      'assigned' => ('Mở quy trình giao hàng', Icons.route_rounded),
      'picking_up' => ('Tiếp tục đến điểm lấy', Icons.storefront_rounded),
      'delivering' => ('Tiếp tục giao hàng', Icons.local_shipping_rounded),
      _ => ('Xem hành trình', Icons.route_rounded),
    };
    return Material(
      color: AppColors.accentLight,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.full,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverRateCustomerAction extends StatelessWidget {
  const DriverRateCustomerAction({
    super.key,
    required this.alreadyRated,
    required this.isLoading,
    required this.onTap,
  });

  final bool alreadyRated;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (alreadyRated) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Đã đánh giá khách hàng',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.star_outline_rounded, size: 18),
        label: const Text('Đánh giá khách hàng'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
    );
  }
}

class DriverAcceptOrderButton extends StatelessWidget {
  const DriverAcceptOrderButton({
    super.key,
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null
          ? AppColors.textMuted.withValues(alpha: 0.24)
          : AppColors.accent,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textOnAccent,
                  ),
                )
              else
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.textOnAccent,
                  size: 17,
                ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  isLoading ? 'Đang nhận...' : 'Nhận đơn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textOnAccent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverTransferOrderButton extends StatelessWidget {
  const DriverTransferOrderButton({
    super.key,
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.warning;
    return Material(
      color: onTap == null
          ? AppColors.textMuted.withValues(alpha: 0.24)
          : color.withValues(alpha: 0.12),
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                const Icon(Icons.swap_horiz_rounded, color: color, size: 17),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  isLoading ? 'Đang chuyển...' : 'Chuyển đơn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverOrderInfoRow extends StatelessWidget {
  const DriverOrderInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor = AppColors.textMuted,
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text.isEmpty ? 'Chưa cập nhật' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class DriverMetaPill extends StatelessWidget {
  const DriverMetaPill({
    super.key,
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? AppColors.accent : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.accentLight : AppColors.bgLight,
        borderRadius: AppRadius.full,
        border: Border.all(
          color: emphasized
              ? AppColors.accent.withValues(alpha: 0.24)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class DriverStatusBadge extends StatelessWidget {
  const DriverStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        statusLabel(status),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
