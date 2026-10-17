import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/driver_navigation_strings.dart';

/// Hiển thị mốc dự kiến có trong đơn; không dùng để kết luận vi phạm.
class DriverDeliveryCountdown extends StatefulWidget {
  const DriverDeliveryCountdown({
    required this.deadline,
    this.now,
    this.compact = false,
    this.dark = true,
    super.key,
  });

  final DateTime? deadline;
  final DateTime Function()? now;
  final bool compact;
  final bool dark;

  @override
  State<DriverDeliveryCountdown> createState() =>
      _DriverDeliveryCountdownState();
}

class _DriverDeliveryCountdownState extends State<DriverDeliveryCountdown>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureTimer();
  }

  @override
  void didUpdateWidget(covariant DriverDeliveryCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _configureTimer();
  }

  void _configureTimer() {
    _timer?.cancel();
    if (widget.deadline != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configureTimer();
      if (mounted) setState(() {});
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.deadline;
    final difference = deadline?.difference((widget.now ?? DateTime.now)());
    final overdue = difference != null && difference.inMicroseconds <= 0;
    final minutes = difference == null
        ? 0
        : (difference.inMicroseconds.abs() / Duration.microsecondsPerMinute)
              .ceil();
    final label = difference == null
        ? DriverNavigationStrings.deliveryDeadlineMissing
        : overdue
        ? DriverNavigationStrings.deliveryMinutesOverdue(minutes)
        : DriverNavigationStrings.deliveryMinutesRemaining(minutes);
    final color = overdue
        ? AppColors.error
        : widget.dark
        ? AppColors.textOnDark
        : AppColors.textSecondary;
    return Semantics(
      // Chỉ thông báo đổi sang quá hạn, không đọc bộ đếm mỗi giây.
      liveRegion: overdue,
      child: Row(
        children: [
          Icon(
            overdue ? Icons.timer_off_rounded : Icons.schedule_rounded,
            color: color,
            size: widget.compact ? 16 : 20,
          ),
          SizedBox(width: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: widget.compact ? 1 : null,
              overflow: widget.compact ? TextOverflow.ellipsis : null,
              style:
                  (widget.compact
                          ? AppTextStyles.labelMedium
                          : AppTextStyles.labelLarge)
                      .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
