import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../driver_monitoring_providers.dart';
import '../../../delivery_eta/order_eta_providers.dart';

class DriverMonitoringGuard extends ConsumerWidget {
  const DriverMonitoringGuard({
    required this.orderId,
    required this.onReleased,
    required this.child,
    this.enabled = true,
    this.onInactive,
    super.key,
  });
  final String orderId;
  final bool enabled;
  final Future<void> Function(String? ticketId) onReleased;
  final Widget child;
  final VoidCallback? onInactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (enabled) {
      ref.listen(driverMonitoringProvider(orderId), (previous, next) {
        final snapshot = next.valueOrNull;
        final departed = snapshot?.state?.departedAt;
        if (departed != null &&
            previous?.valueOrNull?.state?.departedAt != departed) {
          ref.invalidate(orderEtaProvider(orderId));
        }
        if (snapshot?.released != true) {
          if (snapshot != null &&
              const {
                'cancelled',
                'delivered',
                'returned',
                'not_assigned',
                'risk_hold',
              }.contains(snapshot.status)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) onInactive?.call();
            });
          }
          return;
        }
        final key = '$orderId:${snapshot!.supportTicketId}';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final handled = ref.read(handledDriverMonitoringReleasesProvider);
          if (handled.contains(key)) return;
          ref.read(handledDriverMonitoringReleasesProvider.notifier).state = {
            ...handled,
            key,
          };
          unawaited(onReleased(snapshot.supportTicketId));
        });
      });
    }
    return child;
  }
}
