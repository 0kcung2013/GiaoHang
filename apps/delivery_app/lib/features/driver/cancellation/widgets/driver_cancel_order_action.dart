import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/driver_foreground_location_service.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../core/providers/driver_wallet_providers.dart';
import '../dialogs/driver_cancel_order_sheet.dart';
import '../driver_cancellation_providers.dart';
import '../driver_cancellation_strings.dart';
import '../models/driver_cancellation_policy.dart';

/// Dùng chung cho tab Đơn hàng và trang Thông tin đơn, trước khi nhận hàng.
class DriverCancelOrderAction extends ConsumerStatefulWidget {
  const DriverCancelOrderAction({
    super.key,
    required this.order,
    this.pickupConfirmed = false,
    this.onCancelled,
  });
  final OrderModel order;
  final bool pickupConfirmed;
  final VoidCallback? onCancelled;

  @override
  ConsumerState<DriverCancelOrderAction> createState() => _ActionState();
}

class _ActionState extends ConsumerState<DriverCancelOrderAction> {
  bool _opening = false;

  Future<void> _open() async {
    final order = widget.order;
    final driverId = order.driverId;
    if (_opening || driverId == null) return;
    setState(() => _opening = true);
    final repository = ref.read(driverCancellationRepositoryProvider);
    final sessions = ref.read(driverNavSessionsProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final onCancelled = widget.onCancelled;
    var committed = false;
    try {
      final snapshot = await repository.getCancellationState(order.id);
      if (!mounted) return;
      if (!snapshot.policy.canCancel) {
        throw const FormatException(DriverCancellationStrings.unavailable);
      }
      await showDriverCancelOrderSheet(
        context: context,
        policy: snapshot.policy,
        now: snapshot.clock.now,
        onConfirm: (reason) async {
          await repository.cancel(order.id, reason);
          committed = true;
          onCancelled?.call();
          // Card có thể unmount khi Realtime cập nhật. Dùng container/notifier
          // đã lấy trước submit để dọn phiên và đồng bộ khóa sau khi commit.
          try {
            await sessions.remove(order.id);
          } catch (error) {
            debugPrint('[DriverCancellation] navigation cleanup: $error');
          }
          try {
            await DriverForegroundLocationService.stop();
          } catch (error) {
            debugPrint('[DriverCancellation] GPS cleanup: $error');
          }
          container.invalidate(driverAcceptanceStateProvider(driverId));
          container.invalidate(driverByUserIdProvider(driverId));
          container.invalidate(availableOrdersProvider(driverId));
          container.invalidate(driverOrdersProvider(driverId));
          container.invalidate(orderByIdProvider(order.id));
          container.invalidate(driverWalletSummaryProvider);
          container.invalidate(driverWalletTransactionsProvider);
        },
      );
      if (committed) {
        // Đóng cả trang chi tiết mở bằng Navigator.push trước khi về Tổng quan.
        if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
        router?.go('/driver-home');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : DriverCancellationStrings.failed,
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final policy = DriverCancellationPolicy(
      status: order.status,
      pickupConfirmed: widget.pickupConfirmed || order.actualPickedUpAt != null,
      pickupArrivedAt: order.pickupArrivedAt,
    );
    if (order.driverId == null || !policy.canCancel) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
      onPressed: _opening ? null : _open,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        foregroundColor: AppColors.error,
        backgroundColor: AppColors.bgCard,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.22)),
        textStyle: AppTextStyles.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      icon: Icon(
        _opening ? Icons.hourglass_top_rounded : Icons.cancel_outlined,
        size: 20,
      ),
      label: Text(
        _opening
            ? DriverCancellationStrings.submitting
            : DriverCancellationStrings.title,
      ),
    );
  }
}
