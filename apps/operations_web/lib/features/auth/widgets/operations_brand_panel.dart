import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class OperationsBrandPanel extends StatelessWidget {
  const OperationsBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.primary),
        const Positioned(
          right: -110,
          top: -100,
          child: _DecorativeCircle(size: 310, opacity: 0.07),
        ),
        const Positioned(
          left: -90,
          bottom: -120,
          child: _DecorativeCircle(size: 350, opacity: 0.05),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandMark(),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: AppRadius.full,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'TRUNG TÂM VẬN HÀNH',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: const Color(0xFFFFA47F),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl2),
              Text(
                'Vận hành thông minh.\nGiao hàng liền mạch.',
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.textOnDark,
                  fontSize: 38,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Một không gian tập trung để đội ngũ theo dõi, hỗ trợ và '
                'kiểm soát mọi hành trình giao hàng.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: AppSpacing.xl3),
              const Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _FeatureChip(
                    icon: Icons.route_outlined,
                    label: 'Điều phối đơn',
                  ),
                  _FeatureChip(
                    icon: Icons.support_agent_rounded,
                    label: 'Hỗ trợ khách hàng',
                  ),
                  _FeatureChip(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Giám sát hệ thống',
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'GIAOHANG · Operations Console',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textOnDark.withValues(alpha: 0.42),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: AppColors.textOnAccent,
            size: 23,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'GIAOHANG',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textOnDark,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: AppRadius.full,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: 48,
          color: AppColors.accent.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
