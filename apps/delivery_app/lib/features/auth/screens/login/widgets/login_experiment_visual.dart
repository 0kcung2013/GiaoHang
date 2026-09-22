import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../widgets/auth_strings.dart';
import 'login_experiment_tokens.dart';

class LoginExperimentVisualPanel extends StatelessWidget {
  const LoginExperimentVisualPanel({
    super.key,
    required this.isWide,
    this.height,
  });

  final bool isWide;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final resolvedHeight = height ?? (isWide ? 660.0 : 310.0);
    final imageWidth = isWide
        ? 500.0
        : ((resolvedHeight + 64) * (1065 / 1477)).clamp(132.0, 270.0);
    final imageHeight = imageWidth / (1065 / 1477);

    return RepaintBoundary(
      child: AnimatedContainer(
        key: const Key('login-hero-panel'),
        duration: AppDuration.normal,
        curve: AppCurve.decelerate,
        width: double.infinity,
        height: resolvedHeight,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LoginExperimentTokens.heroTop,
              LoginExperimentTokens.heroBottom,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: isWide ? 126 : 58,
              right: isWide ? -36 : -28,
              child: _SoftOrb(
                size: isWide ? 410 : 238,
                color: LoginExperimentTokens.heroGlow.withValues(alpha: 0.3),
              ),
            ),
            Positioned(
              left: isWide ? 44 : 22,
              bottom: isWide ? 78 : 40,
              child: const _ParcelSilhouette(),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: _HeroRoutePainter()),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? AppSpacing.xl4 : AppSpacing.xl2,
                isWide ? AppSpacing.xl4 : AppSpacing.xl,
                isWide ? AppSpacing.xl4 : AppSpacing.xl2,
                AppSpacing.xl3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LoginBrand(),
                  if (isWide) ...[
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: Text(
                        AuthStrings.loginHeroTitle,
                        style: AppTextStyles.displayLarge.copyWith(
                          color: LoginExperimentTokens.ink,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        AuthStrings.loginHeroSubtitle,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: LoginExperimentTokens.ink.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl4),
                  ],
                ],
              ),
            ),
            Positioned(
              right: isWide ? -74 : -24,
              bottom: isWide ? -94 : -92,
              child: Semantics(
                container: true,
                image: true,
                label: AuthStrings.loginIllustrationLabel,
                child: Image.asset(
                  'assets/images/login_courier_hero.png',
                  key: const Key('login-courier-hero'),
                  width: imageWidth,
                  height: imageHeight,
                  fit: BoxFit.contain,
                  cacheWidth: isWide ? 900 : 540,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, loadedSynchronously) {
                    if (loadedSynchronously || frame != null) return child;
                    return Image.asset(
                      'assets/images/app_splash_mascot.png',
                      width: imageWidth,
                      height: imageHeight,
                      fit: BoxFit.contain,
                      cacheWidth: isWide ? 820 : 460,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/app_splash_mascot.png',
                    width: imageWidth,
                    height: imageHeight,
                    fit: BoxFit.contain,
                    cacheWidth: isWide ? 820 : 460,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: LoginExperimentTokens.surface.withValues(alpha: 0.9),
              borderRadius: AppRadius.sm,
              boxShadow: AppShadow.subtle,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              size: 20,
              color: LoginExperimentTokens.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AuthStrings.appName,
            style: AppTextStyles.headingSmall.copyWith(
              color: LoginExperimentTokens.ink,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: LoginExperimentTokens.accent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcelSilhouette extends StatelessWidget {
  const _ParcelSilhouette();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -0.08,
        child: Container(
          width: 72,
          height: 58,
          decoration: BoxDecoration(
            color: LoginExperimentTokens.surface.withValues(alpha: 0.22),
            borderRadius: AppRadius.sm,
            border: Border.all(
              color: LoginExperimentTokens.surface.withValues(alpha: 0.34),
            ),
          ),
          alignment: Alignment.topCenter,
          child: Container(
            width: 18,
            height: 16,
            color: LoginExperimentTokens.surface.withValues(alpha: 0.24),
          ),
        ),
      ),
    );
  }
}

class _HeroRoutePainter extends CustomPainter {
  const _HeroRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LoginExperimentTokens.surface.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(-16, size.height * 0.74)
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.6,
        size.width * 0.3,
        size.height * 0.88,
        size.width * 0.54,
        size.height * 0.72,
      );
    canvas.drawPath(path, paint);
    final dot = Paint()
      ..color = LoginExperimentTokens.surface.withValues(alpha: 0.52);
    canvas
      ..drawCircle(Offset(size.width * 0.07, size.height * 0.69), 4, dot)
      ..drawCircle(Offset(size.width * 0.5, size.height * 0.74), 4, dot);
  }

  @override
  bool shouldRepaint(covariant _HeroRoutePainter oldDelegate) => false;
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
