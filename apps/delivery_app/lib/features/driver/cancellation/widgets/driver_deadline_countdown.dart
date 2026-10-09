import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../driver_cancellation_strings.dart';
import '../models/driver_cancellation_policy.dart';

/// Chỉ vùng đồng hồ rebuild. Mỗi tick tính lại từ mốc tuyệt đối,
/// kể cả sau khi app quay lại foreground.
class DriverDeadlineCountdown extends StatefulWidget {
  const DriverDeadlineCountdown({
    super.key,
    required this.deadline,
    required this.totalDuration,
    this.onExpired,
    this.now = DateTime.now,
    this.builder,
  });

  final DateTime deadline;
  final Duration totalDuration;
  final VoidCallback? onExpired;
  final DateTime Function() now;
  final Widget Function(BuildContext, Duration)? builder;

  @override
  State<DriverDeadlineCountdown> createState() => _CountdownState();
}

class _CountdownState extends State<DriverDeadlineCountdown>
    with WidgetsBindingObserver {
  Timer? _timer;
  late Duration _remaining;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didUpdateWidget(covariant DriverDeadlineCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _start();
  }

  void _start() {
    _timer?.cancel();
    _notified = false;
    _remaining = DriverCancellationPolicy.remaining(
      widget.deadline,
      widget.now(),
    );
    if (_remaining == Duration.zero) {
      _notifyExpiry();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _remaining = DriverCancellationPolicy.remaining(
        widget.deadline,
        widget.now(),
      );
    });
    if (_remaining == Duration.zero) {
      _timer?.cancel();
      _notifyExpiry();
    }
  }

  void _notifyExpiry() {
    if (_notified) return;
    _notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExpired?.call();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) return widget.builder!(context, _remaining);
    final label = DriverCancellationPolicy.formatRemaining(_remaining);
    final total = widget.totalDuration.inMilliseconds;
    final progress = total <= 0
        ? 0.0
        : (_remaining.inMilliseconds / total).clamp(0.0, 1.0);
    return Semantics(
      label: DriverCancellationStrings.countdownLabel,
      value: label,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 104,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  color: AppColors.warning,
                  backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FittedBox(
                  child: Text(
                    label,
                    style: AppTextStyles.mono.copyWith(
                      fontSize: 22,
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
