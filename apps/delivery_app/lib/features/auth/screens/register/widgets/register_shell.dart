import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../widgets/auth_strings.dart';

/// The registration canvas owns responsive composition, not form state.
class RegisterShell extends StatelessWidget {
  const RegisterShell({super.key, required this.child, required this.onBack});

  final Widget child;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.xl2,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: onBack,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.bgCard,
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size(48, 48),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.local_shipping_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        AuthStrings.appName,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AuthStrings.registerTitle,
                                style: AppTextStyles.displayMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                AuthStrings.registerSubtitle,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const ExcludeSemantics(
                          child: SizedBox(
                            width: 76,
                            height: 88,
                            child: CustomPaint(painter: _ParcelPainter()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                    duration: reduceMotion ? Duration.zero : AppDuration.page,
                    curve: AppCurve.decelerate,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: AppRadius.xl2,
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadow.subtle,
                      ),
                      child: child,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        AuthStrings.haveAccount,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: onBack,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size(48, 48),
                          textStyle: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        child: const Text(AuthStrings.backToLogin),
                      ),
                    ],
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

/// A small vector parcel keeps the header crisp without a raster dependency.
class _ParcelPainter extends CustomPainter {
  const _ParcelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 76, size.height / 88);
    final fill = Paint();
    canvas.drawCircle(
      const Offset(40, 46),
      34,
      fill..color = AppColors.accentLight,
    );
    final route = Path()
      ..moveTo(4, 64)
      ..cubicTo(0, 84, 66, 88, 70, 55);
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final top = Path()
      ..moveTo(15, 31)
      ..lineTo(40, 18)
      ..lineTo(65, 31)
      ..lineTo(40, 45)
      ..close();
    final left = Path()
      ..moveTo(15, 31)
      ..lineTo(40, 45)
      ..lineTo(40, 73)
      ..lineTo(15, 59)
      ..close();
    final right = Path()
      ..moveTo(40, 45)
      ..lineTo(65, 31)
      ..lineTo(65, 59)
      ..lineTo(40, 73)
      ..close();
    canvas.drawPath(top, fill..color = AppColors.accent.withValues(alpha: 0.6));
    canvas.drawPath(left, fill..color = AppColors.accent);
    canvas.drawPath(right, fill..color = AppColors.primary);
    canvas.drawPath(
      Path()
        ..moveTo(26, 25)
        ..lineTo(51, 38)
        ..lineTo(51, 49)
        ..lineTo(57, 46)
        ..lineTo(57, 35)
        ..lineTo(32, 22)
        ..close(),
      fill..color = AppColors.bgWarm,
    );
    canvas.drawCircle(const Offset(66, 12), 10, fill..color = AppColors.bgCard);
    canvas.drawPath(
      Path()
        ..moveTo(62, 12)
        ..lineTo(65, 15)
        ..lineTo(70, 9),
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(6, 65), 3, fill..color = AppColors.accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ParcelPainter oldDelegate) => false;
}
