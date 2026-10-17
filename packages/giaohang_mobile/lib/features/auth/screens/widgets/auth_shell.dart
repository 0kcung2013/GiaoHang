import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'auth_strings.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.bgLight)),
          const Positioned(top: 0, left: 0, right: 0, child: _BrandBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.xl3,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: Stack(
                          children: [
                            if (onBack case final callback?)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Semantics(
                                  button: true,
                                  label: 'Quay lại',
                                  child: IconButton(
                                    onPressed: callback,
                                    tooltip: 'Quay lại',
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: AppColors.textOnDark,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                  ),
                                ),
                              ),
                            const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.only(top: AppSpacing.xl2),
                                child: _BrandIdentity(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.xl2),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: AppRadius.xl2,
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadow.card,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.headingLarge.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              subtitle,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl2),
                            child,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBackdrop extends StatelessWidget {
  const _BrandBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.bgDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -54,
            right: -34,
            child: _AccentCircle(
              size: 164,
              color: AppColors.accent.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: 26,
            left: -42,
            child: _AccentCircle(
              size: 118,
              color: AppColors.info.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentCircle extends StatelessWidget {
  const _AccentCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _BrandIdentity extends StatelessWidget {
  const _BrandIdentity();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.xl,
            boxShadow: AppShadow.accentGlow,
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            size: 34,
            color: AppColors.textOnAccent,
            semanticLabel: 'Ứng dụng giao hàng',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AuthStrings.appName,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AuthStrings.appTagline,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textOnDark.withValues(alpha: 0.76),
          ),
        ),
      ],
    );
  }
}
