import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../driver_home_strings.dart';

class DriverHomeBanner extends StatelessWidget {
  const DriverHomeBanner({super.key, required this.isOnline});

  static const _assetPath = 'assets/images/driver_home_courier_banner_v2.png';
  static const _assetAspectRatio = 1.78;
  static const _assetPixelWidth = 1672;

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final subtitle = isOnline
        ? DriverHomeStrings.bannerOnlineSubtitle
        : DriverHomeStrings.bannerOfflineSubtitle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedLayout = constraints.maxWidth < 340 || textScale > 1.3;
        final cacheWidth =
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(1, _assetPixelWidth);

        return Semantics(
          container: true,
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.xl2,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.14),
              ),
              boxShadow: AppShadow.card,
            ),
            child: useStackedLayout
                ? _StackedBanner(subtitle: subtitle, cacheWidth: cacheWidth)
                : AspectRatio(
                    aspectRatio: _assetAspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _BannerImage(cacheWidth: cacheWidth),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.48,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: _BannerCopy(subtitle: subtitle),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _StackedBanner extends StatelessWidget {
  const _StackedBanner({required this.subtitle, required this.cacheWidth});

  final String subtitle;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: _BannerCopy(subtitle: subtitle),
        ),
        AspectRatio(
          aspectRatio: DriverHomeBanner._assetAspectRatio,
          child: _BannerImage(cacheWidth: cacheWidth),
        ),
      ],
    );
  }
}

class _BannerCopy extends StatelessWidget {
  const _BannerCopy({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DriverHomeStrings.bannerTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.cacheWidth});

  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      DriverHomeBanner._assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      semanticLabel: DriverHomeStrings.bannerSemanticLabel,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppColors.accentLight,
        child: Center(
          child: Icon(
            Icons.local_shipping_rounded,
            size: 32,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
