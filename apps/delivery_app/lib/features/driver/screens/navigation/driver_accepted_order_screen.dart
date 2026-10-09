import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import 'driver_navigation_screen.dart';
import 'widgets/driver_order_cancellation_guard.dart';
import '../home/utils/driver_home_formatters.dart';
import '../home/widgets/driver_order_offer_summary.dart';

void openDriverAcceptedOrder(BuildContext context, String orderId) {
  prepareDriverAcceptedOrderNavigation(context, orderId)();
}

/// Giữ navigation entry trước khi Realtime gỡ thẻ đơn khỏi màn hình.
VoidCallback prepareDriverAcceptedOrderNavigation(
  BuildContext context,
  String orderId,
) {
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context);
  return () {
    if (!navigator.mounted) return;
    container.invalidate(orderByIdProvider(orderId));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => DriverOrderCancellationGuard(
          orderId: orderId,
          onCancelled: () => container
              .read(driverNavSessionsProvider.notifier)
              .remove(orderId),
          child: DriverAcceptedOrderScreen(orderId: orderId),
        ),
      ),
    );
  };
}

/// Đọc lại đơn đã được backend xác nhận trước khi hiển thị hàng và quy trình giao.
class DriverAcceptedOrderScreen extends ConsumerWidget {
  const DriverAcceptedOrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));
    final accepted = order.valueOrNull;
    if (accepted != null &&
        accepted.driverId?.isNotEmpty == true &&
        isActiveDriverOrder(accepted)) {
      return DriverNavigationScreen(order: accepted);
    }
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        foregroundColor: AppColors.primary,
        title: Text(
          DriverOrderPresentationStrings.details,
          style: AppTextStyles.headingSmall,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: order.isLoading
              ? const LinearProgressIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.accentLight,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DriverOrderPresentationStrings.loadError,
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(orderByIdProvider(orderId)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(48, 48),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.md,
                        ),
                        textStyle: AppTextStyles.labelLarge,
                      ),
                      child: const Text(DriverOrderPresentationStrings.retry),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
