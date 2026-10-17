import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/location/driver_foreground_location_service.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/driver_nav_session_provider.dart';
import '../../../core/providers/driver_wallet_providers.dart';
import '../../../core/providers/location_providers.dart';
import 'dialogs/driver_monitoring_release_dialog.dart';

Future<void> handleDriverMonitoringRelease(
  BuildContext context,
  WidgetRef ref, {
  required String orderId,
  required String userId,
  String? ticketId,
}) async {
  ref.read(activeDriverNavigationOrderProvider.notifier).state = null;
  try {
    await ref.read(driverNavSessionsProvider.notifier).remove(orderId);
  } catch (error) {
    debugPrint('[DriverMonitoring] Cannot clear local navigation: $error');
  }
  try {
    await DriverForegroundLocationService.stop();
  } catch (error) {
    debugPrint('[DriverMonitoring] Cannot stop foreground GPS: $error');
  }
  if (!context.mounted) return;
  ref.invalidate(driverOrdersProvider(userId));
  ref.invalidate(availableOrdersProvider(userId));
  ref.invalidate(driverByUserIdProvider(userId));
  ref.invalidate(orderByIdProvider(orderId));
  ref.invalidate(driverWalletSummaryProvider);
  ref.invalidate(driverWalletTransactionsProvider);
  final navigator = Navigator.of(context, rootNavigator: true);
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go('/driver-home');
  } else {
    navigator.popUntil((route) => route.isFirst);
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigator.mounted) {
      showDriverMonitoringReleaseDialog(navigator.context, ticketId: ticketId);
    }
  });
}
