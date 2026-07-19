import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../notifications/widgets/notification_bell_button.dart';

class DashboardHeader extends StatelessWidget {
  final String userName;
  final int activeCount;
  final bool hasActiveDelivery;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.activeCount,
    required this.hasActiveDelivery,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDuration.page,
      switchInCurve: AppCurve.decelerate,
      switchOutCurve: AppCurve.accelerate,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: ValueKey('header_$userName'),
      children: [
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: AppTextStyles.displayMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildSubtitle(),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const NotificationBellButton(),
            const SizedBox(width: AppSpacing.xs),
            _buildHeroIcon(),
          ],
        ),
        const SizedBox(height: AppSpacing.xl2),
        _buildCreateOrderButton(context),
      ],
    );
  }

  Widget _buildSubtitle() {
    if (hasActiveDelivery) {
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: AppShadow.accentGlow,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              activeCount == 1
                  ? '1 đơn đang được giao đến bạn'
                  : '$activeCount đơn đang được giao đến bạn',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      'Sẵn sàng tạo đơn giao hàng mới',
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }

  Widget _buildHeroIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: AppDuration.slow,
      curve: AppCurve.spring,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.accent,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateOrderButton(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: AppRadius.full,
      elevation: 0,
      shadowColor: AppColors.accent.withValues(alpha: 0.35),
      child: InkWell(
        onTap: () => context.push('/customer/create-order'),
        borderRadius: AppRadius.full,
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: AppRadius.full,
            boxShadow: AppShadow.accentGlow,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_rounded,
                  color: AppColors.textOnAccent,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Tạo đơn mới',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textOnAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng, $userName';
    if (hour < 17) return 'Chào buổi chiều, $userName';
    return 'Chào buổi tối, $userName';
  }
}
