import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../driver_home_strings.dart';

class DriverOfferCountdown extends StatefulWidget {
  const DriverOfferCountdown({
    super.key,
    required this.expiresAt,
    this.offerDuration = const Duration(seconds: 45),
    this.now,
  });

  final DateTime expiresAt;
  final Duration offerDuration;
  final DateTime Function()? now;

  @override
  State<DriverOfferCountdown> createState() => _DriverOfferCountdownState();
}

class _DriverOfferCountdownState extends State<DriverOfferCountdown> {
  Timer? _ticker;

  DateTime get _now => (widget.now ?? DateTime.now)();

  int get _remainingSeconds {
    final remainingMilliseconds = widget.expiresAt
        .difference(_now)
        .inMilliseconds;
    if (remainingMilliseconds <= 0) return 0;
    return (remainingMilliseconds + 999) ~/ 1000;
  }

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant DriverOfferCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_remainingSeconds == 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remainingSeconds == 0) {
        _ticker?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = _remainingSeconds;
    if (remainingSeconds == 0) {
      return Semantics(
        liveRegion: true,
        label: DriverHomeStrings.offerExpiredLabel,
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_rounded,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    DriverHomeStrings.offerExpiredLabel,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalSeconds = widget.offerDuration.inSeconds.clamp(1, 86400);
    final progress = (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    return Semantics(
      liveRegion: true,
      label: DriverHomeStrings.offerCountdownSemantic(remainingSeconds),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      DriverHomeStrings.offerCountdownLabel,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(remainingSeconds),
                    style: AppTextStyles.mono.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadius.full,
                child: Container(
                  height: 5,
                  color: AppColors.bgCard,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: const ColoredBox(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                DriverHomeStrings.offerAutoTransferHint,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutesPart = (seconds ~/ 60).toString().padLeft(2, '0');
    final secondsPart = (seconds % 60).toString().padLeft(2, '0');
    return '$minutesPart:$secondsPart';
  }
}
