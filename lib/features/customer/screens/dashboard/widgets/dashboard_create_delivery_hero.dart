import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_theme.dart';
import '../dashboard_strings.dart';

class DashboardCreateDeliveryHero extends StatelessWidget {
  const DashboardCreateDeliveryHero({super.key, required this.isFirstDelivery});

  final bool isFirstDelivery;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artworkHeight = math.min(constraints.maxWidth / 1.78, 260.0);
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final horizontalInset = constraints.maxWidth < 360
            ? AppSpacing.md
            : AppSpacing.lg;

        return Semantics(
          container: true,
          label: DashboardStrings.createDeliverySemantics(
            isFirstDelivery: isFirstDelivery,
          ),
          child: Column(
            children: [
              _ArtworkBanner(
                height: artworkHeight,
                horizontalInset: horizontalInset,
                copyWidth: constraints.maxWidth * 0.53,
                showTopAction: textScale <= 1.3,
                onTap: () => _openCreateOrder(context),
              ),
              Transform.translate(
                offset: const Offset(0, -AppSpacing.xl2),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalInset),
                  child: _RoutePromptCard(
                    onTap: () => _openCreateOrder(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCreateOrder(BuildContext context) {
    context.push('/customer/create-order');
  }
}

class _ArtworkBanner extends StatelessWidget {
  const _ArtworkBanner({
    required this.height,
    required this.horizontalInset,
    required this.copyWidth,
    required this.showTopAction,
    required this.onTap,
  });

  final double height;
  final double horizontalInset;
  final double copyWidth;
  final bool showTopAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.xl2,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.12)),
        boxShadow: AppShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _CourierArtwork(),
          Positioned(
            left: horizontalInset,
            top: AppSpacing.xl2,
            width: math.max(148, copyWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DashboardStrings.heroTitle,
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: -0.6,
                  ),
                ),
                if (showTopAction) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 48,
                    child: TextButton.icon(
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        minimumSize: const Size(48, 48),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(
                        DashboardStrings.createDelivery,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierArtwork extends StatelessWidget {
  const _CourierArtwork();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: DashboardStrings.courierIllustrationSemantics,
      child: Image.asset(
        DashboardStrings.courierIllustrationAsset,
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        filterQuality: FilterQuality.medium,
        cacheWidth: 1400,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _RoutePromptCard extends StatelessWidget {
  const _RoutePromptCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${DashboardStrings.pickupPrompt}. '
          '${DashboardStrings.deliveryPrompt}',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl2,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.elevated,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.xl2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.accent.withValues(alpha: 0.09),
            highlightColor: AppColors.accent.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      children: [
                        _AddressPrompt(
                          icon: Icons.radio_button_checked_rounded,
                          color: AppColors.info,
                          label: DashboardStrings.pickupPrompt,
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 42),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        _AddressPrompt(
                          icon: Icons.location_on_rounded,
                          color: AppColors.accent,
                          label: DashboardStrings.deliveryPrompt,
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      color: AppColors.accent,
                      size: 22,
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

class _AddressPrompt extends StatelessWidget {
  const _AddressPrompt({
    required this.icon,
    required this.color,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Icon(icon, color: color, size: emphasized ? 25 : 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style:
                  (emphasized
                          ? AppTextStyles.headingMedium
                          : AppTextStyles.bodyMedium)
                      .copyWith(
                        color: emphasized
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: emphasized
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
