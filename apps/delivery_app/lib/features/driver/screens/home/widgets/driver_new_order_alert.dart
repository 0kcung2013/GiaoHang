import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../utils/driver_home_formatters.dart';

/// Banner luôn được mount để phát hiện chính xác đơn mới từ realtime.
///
/// Snapshot đầu tiên chỉ hiển thị UI. Âm báo/rung chỉ chạy khi một order ID mới
/// xuất hiện sau snapshot đó, tránh báo lặp khi tài xế mở lại màn hình.
class DriverNewOrderAlert extends StatefulWidget {
  const DriverNewOrderAlert({
    super.key,
    required this.orders,
    required this.pickupDistancesMeters,
  });

  final List<OrderModel> orders;
  final Map<String, double> pickupDistancesMeters;

  @override
  State<DriverNewOrderAlert> createState() => _DriverNewOrderAlertState();
}

class _DriverNewOrderAlertState extends State<DriverNewOrderAlert>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _arrivalController;
  late Set<String> _knownOrderIds;

  @override
  void initState() {
    super.initState();
    _knownOrderIds = widget.orders.map((order) => order.id).toSet();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _arrivalController = AnimationController(
      vsync: this,
      duration: AppDuration.slow,
      value: 0,
    );
    if (widget.orders.isNotEmpty) {
      _pulseController.repeat(reverse: true);
      _arrivalController.forward();
      unawaited(_playArrivalFeedback());
    }
  }

  @override
  void didUpdateWidget(covariant DriverNewOrderAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.orders.map((order) => order.id).toSet();
    final hasNewArrival = currentIds.difference(_knownOrderIds).isNotEmpty;
    _knownOrderIds = currentIds;

    if (widget.orders.isEmpty) {
      _pulseController.stop();
      _arrivalController.reverse();
      return;
    }

    if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }

    if (hasNewArrival) {
      _arrivalController.forward(from: 0);
      unawaited(_playArrivalFeedback());
    } else if (oldWidget.orders.isEmpty) {
      _arrivalController.forward(from: 0);
    }
  }

  Future<void> _playArrivalFeedback() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Một số nền tảng/web không cung cấp system alert.
    }
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Thiết bị không hỗ trợ rung vẫn hiển thị animation bình thường.
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) return const SizedBox.shrink();

    final nearestDistance = widget.pickupDistancesMeters.values.isEmpty
        ? null
        : widget.pickupDistancesMeters.values.reduce(
            (current, next) => current < next ? current : next,
          );
    final count = widget.orders.length;

    return Semantics(
      liveRegion: true,
      label: '$count đơn hàng mới đang chờ nhận',
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _arrivalController,
          curve: AppCurve.decelerate,
        ),
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _arrivalController,
                  curve: AppCurve.decelerate,
                ),
              ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFFFF8A4C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.xl,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = _pulseController.value;
                    return Transform.scale(
                      scale: 0.96 + pulse * 0.08,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.bgCard.withValues(
                                alpha: 0.22 + pulse * 0.28,
                              ),
                              blurRadius: 12 + pulse * 12,
                              spreadRadius: pulse * 3,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 1
                            ? 'Có đơn mới đang chờ'
                            : 'Có $count đơn đang chờ',
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        nearestDistance == null
                            ? 'Kiểm tra thông tin và nhận đơn phù hợp.'
                            : 'Đơn gần nhất ${pickupDistanceText(nearestDistance)}.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textOnDark.withValues(alpha: 0.12),
                    borderRadius: AppRadius.full,
                    border: Border.all(
                      color: AppColors.textOnDark.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    count.toString(),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textOnAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
