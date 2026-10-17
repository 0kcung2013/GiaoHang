import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/customer_providers.dart';

class DriverOrderCancellationGuard extends ConsumerStatefulWidget {
  const DriverOrderCancellationGuard({
    super.key,
    required this.orderId,
    required this.onCancelled,
    required this.child,
  });

  final String orderId;
  final FutureOr<void> Function() onCancelled;
  final Widget child;

  @override
  ConsumerState<DriverOrderCancellationGuard> createState() =>
      _DriverOrderCancellationGuardState();
}

class _DriverOrderCancellationGuardState
    extends ConsumerState<DriverOrderCancellationGuard> {
  String? _lastHandledEventId;

  @override
  void didUpdateWidget(covariant DriverOrderCancellationGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      _lastHandledEventId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(driverOrderCancellationEventProvider, (previous, next) {
      if (next == null ||
          next.orderId != widget.orderId ||
          next.eventId == _lastHandledEventId) {
        return;
      }

      _lastHandledEventId = next.eventId;
      final navigator = Navigator.of(context);
      final cleanup = widget.onCancelled;
      final orderId = widget.orderId;
      unawaited(_closeAndCleanup(navigator, cleanup, orderId));
    });

    return widget.child;
  }

  Future<void> _closeAndCleanup(
    NavigatorState navigator,
    FutureOr<void> Function() cleanup,
    String orderId,
  ) async {
    await navigator.maybePop();
    try {
      await Future<void>.sync(cleanup);
    } catch (error) {
      debugPrint(
        '[DriverOrderCancellationGuard] cleanup failed '
        'orderId=$orderId: $error',
      );
    }
  }
}
