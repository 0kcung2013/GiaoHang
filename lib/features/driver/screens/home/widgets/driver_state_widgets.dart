import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

// ─── Shared primitive ──────────────────────────────────────────────────────

class DriverSectionCard extends StatelessWidget {
  final Widget child;

  const DriverSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: child,
    );
  }
}

// ─── Loading ───────────────────────────────────────────────────────────────

class DriverLoadingState extends StatelessWidget {
  const DriverLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _LoadingBlock(height: 168),
        SizedBox(height: AppSpacing.xl2),
        _LoadingBlock(height: 112),
        SizedBox(height: AppSpacing.xl2),
        _LoadingBlock(height: 220),
        SizedBox(height: AppSpacing.xl2),
        _LoadingBlock(height: 240),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final double height;

  const _LoadingBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.info.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

// ─── Error ─────────────────────────────────────────────────────────────────

class DriverErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const DriverErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return DriverMessageState(
      icon: Icons.error_outline_rounded,
      title: 'Không tải được dữ liệu tài xế',
      message: 'Vui lòng kiểm tra kết nối và thử lại.',
      actionLabel: 'Thử lại',
      onAction: onRetry,
      color: AppColors.error,
    );
  }
}

// ─── Generic message state ─────────────────────────────────────────────────

class DriverMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  const DriverMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color = AppColors.info,
  });

  @override
  Widget build(BuildContext context) {
    return DriverSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.lg,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _StateActionButton(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class _StateActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StateActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.info,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textOnAccent,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Missing driver profile ─────────────────────────────────────────────────

class MissingDriverProfileState extends StatelessWidget {
  const MissingDriverProfileState({super.key});

  @override
  Widget build(BuildContext context) {
    return DriverSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadius.xl,
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: AppColors.warning,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Chưa có hồ sơ tài xế',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tài khoản này đã đăng nhập nhưng chưa được liên kết với bảng tài xế. Vui lòng liên hệ admin để kích hoạt hồ sơ giao hàng.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
