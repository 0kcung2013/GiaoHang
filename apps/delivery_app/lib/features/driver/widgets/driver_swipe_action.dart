import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';

/// Thanh gạt xác nhận dùng chung cho các mốc hành trình của tài xế.
class DriverSwipeAction extends StatefulWidget {
  const DriverSwipeAction({
    required this.label,
    required this.accent,
    required this.icon,
    required this.onCompleted,
    this.loading = false,
    this.dark = false,
    super.key,
  });

  static const semanticHint = 'Gạt sang phải để xác nhận';

  final String label;
  final Color accent;
  final IconData icon;
  final VoidCallback? onCompleted;
  final bool loading;
  final bool dark;

  @override
  State<DriverSwipeAction> createState() => _DriverSwipeActionState();
}

class _DriverSwipeActionState extends State<DriverSwipeAction> {
  static const _height = 56.0;
  static const _padding = 4.0;
  static const _darkEndPadding = AppSpacing.sm;
  static const _thumbSize = 48.0;
  static const _completionThreshold = 0.72;

  double _progress = 0;
  bool _dragging = false;
  bool _completing = false;

  bool get _enabled => widget.onCompleted != null && !widget.loading;

  @override
  void didUpdateWidget(covariant DriverSwipeAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _progress != 0) {
      _progress = 0;
      _dragging = false;
      _completing = false;
    }
  }

  void _updateDrag(DragUpdateDetails details, double travel) {
    if (!_enabled || _completing || travel <= 0) return;
    setState(() {
      _dragging = true;
      _progress = (_progress + details.delta.dx / travel)
          .clamp(0.0, 1.0)
          .toDouble();
    });
  }

  Future<void> _endDrag() async {
    if (!_enabled || _completing) return;
    if (_progress < _completionThreshold) {
      setState(() {
        _dragging = false;
        _progress = 0;
      });
      return;
    }

    setState(() {
      _dragging = false;
      _completing = true;
      _progress = 1;
    });
    unawaited(HapticFeedback.mediumImpact());
    widget.onCompleted?.call();
    await Future<void>.delayed(AppDuration.fast);
    if (!mounted) return;
    setState(() {
      _completing = false;
      _progress = 0;
    });
  }

  void _activateFromSemantics() {
    if (!_enabled || _completing) return;
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.dark
        ? AppColors.textOnDark
        : AppColors.textPrimary;
    final mutedForeground = widget.dark
        ? AppColors.textOnDark.withValues(alpha: 0.55)
        : AppColors.textMuted;

    return Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      label: widget.label,
      hint: DriverSwipeAction.semanticHint,
      onTap: _enabled ? _activateFromSemantics : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final endPadding = widget.dark ? _darkEndPadding : _padding;
          final travel =
              (constraints.maxWidth - _thumbSize - _padding - endPadding)
                  .clamp(0.0, double.infinity)
                  .toDouble();
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _enabled
                ? (details) => _updateDrag(details, travel)
                : null,
            onHorizontalDragEnd: _enabled ? (_) => _endDrag() : null,
            onHorizontalDragCancel: _enabled ? _endDrag : null,
            child: AnimatedContainer(
              key: const Key('driver-swipe-track'),
              duration: AppDuration.fast,
              clipBehavior: Clip.antiAlias,
              width: double.infinity,
              height: _height,
              decoration: BoxDecoration(
                color: _enabled
                    ? widget.accent.withValues(alpha: widget.dark ? 0.2 : 0.12)
                    : AppColors.border.withValues(
                        alpha: widget.dark ? 0.16 : 0.7,
                      ),
                borderRadius: AppRadius.full,
                border: Border.all(
                  color: _enabled
                      ? widget.accent.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 58),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: _enabled ? foreground : mutedForeground,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.md,
                    child: Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      size: 22,
                      color: _enabled
                          ? widget.accent.withValues(alpha: 0.8)
                          : mutedForeground,
                    ),
                  ),
                  AnimatedPositioned(
                    duration: _dragging ? Duration.zero : AppDuration.fast,
                    curve: AppCurve.decelerate,
                    left: _padding + travel * _progress,
                    top: _padding,
                    child: DecoratedBox(
                      key: const Key('driver-swipe-thumb'),
                      decoration: BoxDecoration(
                        color: _enabled ? widget.accent : AppColors.bgCard,
                        borderRadius: AppRadius.full,
                        boxShadow: _enabled ? AppShadow.subtle : const [],
                      ),
                      child: SizedBox(
                        width: _thumbSize,
                        height: _thumbSize,
                        child: Icon(
                          widget.loading ? Icons.sync_rounded : widget.icon,
                          size: 22,
                          color: _enabled
                              ? AppColors.textOnAccent
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
