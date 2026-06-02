import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

class SlideStatusAction extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onConfirmed;

  const SlideStatusAction({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onConfirmed,
  });

  @override
  State<SlideStatusAction> createState() => _SlideStatusActionState();
}

class _SlideStatusActionState extends State<SlideStatusAction> {
  static const _height = 48.0;
  static const _thumbSize = 40.0;
  static const _padding = 4.0;
  double _drag = 0;

  bool get _disabled => widget.isLoading || widget.onConfirmed == null;

  void _updateDrag(double delta, double width) {
    if (_disabled) return;
    final maxDrag = width - _thumbSize - (_padding * 2);
    if (maxDrag <= 0) return;
    setState(() => _drag = (_drag + delta).clamp(0, maxDrag));
  }

  void _finishDrag(double width) {
    if (_disabled) return;
    final maxDrag = width - _thumbSize - (_padding * 2);
    final confirmed = maxDrag > 0 && _drag >= maxDrag * 0.82;
    setState(() => _drag = 0);
    if (confirmed) widget.onConfirmed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final progress = width <= _thumbSize
            ? 0.0
            : (_drag / (width - _thumbSize - (_padding * 2))).clamp(0.0, 1.0);

        return GestureDetector(
          onHorizontalDragUpdate: (details) =>
              _updateDrag(details.primaryDelta ?? 0, width),
          onHorizontalDragEnd: (_) => _finishDrag(width),
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: _disabled
                  ? AppColors.textMuted.withValues(alpha: 0.18)
                  : AppColors.accentLight,
              borderRadius: AppRadius.full,
              border: Border.all(
                color: _disabled
                    ? AppColors.border
                    : AppColors.accent.withValues(alpha: 0.24),
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: AppRadius.full,
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl3,
                    ),
                    child: Text(
                      widget.isLoading ? 'Đang cập nhật...' : widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: _disabled
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 120),
                  left: _padding + _drag,
                  top: _padding,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: _disabled ? AppColors.textMuted : AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: _disabled ? null : AppShadow.accentGlow,
                    ),
                    child: widget.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnAccent,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.textOnAccent,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
