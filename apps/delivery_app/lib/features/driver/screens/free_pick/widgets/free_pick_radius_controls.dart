import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../free_pick_strings.dart';
import '../utils/free_pick_radius.dart';

class FreePickRadiusControls extends StatelessWidget {
  const FreePickRadiusControls({
    super.key,
    required this.radiusMeters,
    required this.onIncrease,
    required this.onDecrease,
  });

  final double radiusMeters;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final canIncrease = radiusMeters < freePickMaximumRadiusMeters;
    final canDecrease = radiusMeters > freePickDefaultRadiusMeters;

    return Semantics(
      container: true,
      label: FreePickStrings.radiusSemantics(radiusMeters),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bgCard.withValues(alpha: 0.96),
          borderRadius: AppRadius.full,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RadiusButton(
                key: const Key('free-pick-radius-increase'),
                icon: Icons.add_rounded,
                tooltip: FreePickStrings.increaseRadius,
                onPressed: canIncrease ? onIncrease : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: SizedBox(
                  width: 56,
                  child: Text(
                    FreePickStrings.radiusValue(radiusMeters),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              _RadiusButton(
                key: const Key('free-pick-radius-decrease'),
                icon: Icons.remove_rounded,
                tooltip: FreePickStrings.decreaseRadius,
                onPressed: canDecrease ? onDecrease : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadiusButton extends StatelessWidget {
  const _RadiusButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textOnAccent,
        backgroundColor: AppColors.accent,
        disabledForegroundColor: AppColors.textMuted,
        disabledBackgroundColor: AppColors.bgLight,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 24),
    );
  }
}
