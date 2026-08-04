import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../core/models/order_model.dart';
import '../../../core/providers/customer_providers.dart';

class OrderAssignmentStatusCard extends ConsumerStatefulWidget {
  const OrderAssignmentStatusCard({
    super.key,
    required this.order,
    this.onCancelled,
  });

  final OrderModel order;
  final VoidCallback? onCancelled;

  @override
  ConsumerState<OrderAssignmentStatusCard> createState() =>
      _OrderAssignmentStatusCardState();
}

class _OrderAssignmentStatusCardState
    extends ConsumerState<OrderAssignmentStatusCard> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  DateTime? _localDeadline;
  bool _expirationReported = false;
  bool _isRetrying = false;
  bool _isCancelling = false;

  DateTime get _deadline => _localDeadline ?? widget.order.assignmentDeadline;

  bool get _isTimedOut {
    if (_localDeadline != null) return !_deadline.isAfter(_now);
    return widget.order.isAssignmentTimedOutAt(_now);
  }

  Duration get _remaining {
    final value = _deadline.difference(_now);
    return value.isNegative ? Duration.zero : value;
  }

  @override
  void initState() {
    super.initState();
    _expirationReported =
        widget.order.assignmentTimedOutAt != null ||
        !widget.order.canWaitForDriver;
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant OrderAssignmentStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final deadlineChanged =
        oldWidget.order.assignmentExpiresAt != widget.order.assignmentExpiresAt;
    final timeoutChanged =
        oldWidget.order.assignmentTimedOutAt !=
        widget.order.assignmentTimedOutAt;
    final statusChanged = oldWidget.order.status != widget.order.status;

    if (deadlineChanged || timeoutChanged || statusChanged) {
      _localDeadline = null;
      _expirationReported =
          widget.order.assignmentTimedOutAt != null ||
          !widget.order.canWaitForDriver;
      _now = DateTime.now();
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (!widget.order.canWaitForDriver) return;

    if (_isTimedOut) {
      unawaited(_reportExpiration());
      return;
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      if (_isTimedOut) {
        _ticker?.cancel();
        unawaited(_reportExpiration());
      }
    });
  }

  Future<void> _reportExpiration() async {
    if (_expirationReported || !widget.order.canWaitForDriver) return;
    _expirationReported = true;
    try {
      await ref
          .read(customerOrderServiceProvider)
          .markOrderAssignmentTimedOut(widget.order.id);
      _invalidateOrderData();
    } catch (_) {
      // The server still rejects late claims even if this best-effort marker
      // cannot be written while the customer is temporarily offline.
    }
  }

  Future<void> _retryAssignment() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      final deadline = await ref
          .read(customerOrderServiceProvider)
          .retryOrderAssignment(widget.order.id);
      if (!mounted) return;
      setState(() {
        _localDeadline = deadline;
        _now = DateTime.now();
        _expirationReported = false;
      });
      _startTicker();
      _invalidateOrderData();
      _showMessage('Đã bắt đầu tìm lại tài xế trong 15 phút.');
    } catch (error) {
      if (mounted) {
        _showMessage(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _cancelOrder() async {
    if (_isCancelling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: AppColors.error,
              size: 26,
            ),
          ),
          title: Text(
            'Hủy đơn hàng?',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Đơn chưa có tài xế. Bạn có chắc muốn kết thúc yêu cầu giao hàng này?',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Giữ đơn',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textOnAccent,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.full,
                ),
              ),
              child: const Text('Hủy đơn'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .cancelOrder(
            widget.order.id,
            widget.order.customerId,
            statusNote: 'Khách hàng hủy sau khi chưa tìm thấy tài xế.',
          );
      _invalidateOrderData();
      widget.onCancelled?.call();
    } catch (error) {
      if (mounted) {
        _showMessage(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _invalidateOrderData() {
    ref.invalidate(orderByIdProvider(widget.order.id));
    ref.invalidate(customerOrdersProvider(widget.order.customerId));
    ref.invalidate(recentOrdersProvider(widget.order.customerId));
    ref.invalidate(activeOrderProvider(widget.order.customerId));
    ref.invalidate(orderStatusLogsProvider(widget.order.id));
    final trackingCode = widget.order.trackingCode.trim();
    if (trackingCode.isNotEmpty) {
      ref.invalidate(orderByTrackingCodeProvider(trackingCode));
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textOnAccent,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.order.canWaitForDriver) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: AppDuration.normal,
      switchInCurve: AppCurve.decelerate,
      switchOutCurve: AppCurve.accelerate,
      child: _isTimedOut
          ? _AssignmentTimedOutView(
              key: const ValueKey('assignment-timed-out'),
              isRetrying: _isRetrying,
              isCancelling: _isCancelling,
              onRetry: _retryAssignment,
              onCancel: _cancelOrder,
            )
          : _AssignmentWaitingView(
              key: const ValueKey('assignment-waiting'),
              remaining: _remaining,
            ),
    );
  }
}

class _AssignmentWaitingView extends StatelessWidget {
  const _AssignmentWaitingView({super.key, required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = OrderModel.assignmentWindow.inSeconds;
    final progress = (remaining.inSeconds / totalSeconds).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentLight, AppColors.bgCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  _formatCountdown(remaining),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_search_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Đang tìm tài xế',
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hệ thống đang chờ tài xế phù hợp nhận đơn của bạn.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentTimedOutView extends StatelessWidget {
  const _AssignmentTimedOutView({
    super.key,
    required this.isRetrying,
    required this.isCancelling,
    required this.onRetry,
    required this.onCancel,
  });

  final bool isRetrying;
  final bool isCancelling;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isBusy = isRetrying || isCancelling;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              color: AppColors.error,
              size: 27,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Chưa tìm thấy tài xế',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chưa có tài xế nhận đơn trong vòng 15 phút. Bạn có thể bắt đầu tìm lại hoặc hủy đơn.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.45),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.full,
                    ),
                  ),
                  child: isCancelling
                      ? const _ButtonSpinner(color: AppColors.error)
                      : const Text('Hủy đơn'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    disabledBackgroundColor: AppColors.accentLight,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.full,
                    ),
                  ),
                  icon: isRetrying
                      ? const SizedBox.shrink()
                      : const Icon(Icons.refresh_rounded, size: 19),
                  label: isRetrying
                      ? const _ButtonSpinner(color: AppColors.accent)
                      : const Text('Tìm lại'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

String _formatCountdown(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
