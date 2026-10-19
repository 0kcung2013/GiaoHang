import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../driver_monitoring_providers.dart';

// Chia sẻ giữa Shell và Map để không hiện lại khi chuyển màn hình.
final _shownProvider = StateProvider<Set<String>>((ref) => {});

class DriverDepartureAlert extends ConsumerStatefulWidget {
  const DriverDepartureAlert({
    required this.orderId,
    required this.enabled,
    required this.child,
    this.pickupArrivedAt,
    super.key,
  });

  final String orderId;
  final bool enabled;
  final Widget child;
  final DateTime? pickupArrivedAt;

  @override
  ConsumerState<DriverDepartureAlert> createState() =>
      _DriverDepartureAlertState();
}

class _DriverDepartureAlertState extends ConsumerState<DriverDepartureAlert> {
  DialogRoute<void>? _route;
  String? _visibleKey;

  void _close() {
    final route = _route;
    _route = null;
    _visibleKey = null;
    if (route?.navigator != null) route!.navigator!.removeRoute(route);
  }

  void _sync() {
    if (!mounted) return;
    final value = widget.enabled
        ? ref.read(driverMonitoringProvider(widget.orderId))
        : null;
    final snapshot = value?.valueOrNull;
    final state = snapshot?.state;
    // Arrival is confirmed by its own RPC before the independent GPS monitor
    // necessarily catches up. Only use confirmation for this assignment.
    final arrived = widget.pickupArrivedAt;
    final pickupConfirmed =
        arrived != null && state != null && !arrived.isBefore(state.acceptedAt);
    final eligible =
        value?.hasError == false &&
        snapshot != null &&
        !snapshot.released &&
        const {'assigned', 'picking_up'}.contains(snapshot.status) &&
        state != null &&
        !pickupConfirmed &&
        !state.hasStarted &&
        !state.isReclaimed &&
        state.incidentAt == null;
    final minutes = eligible
        ? state.elapsedAt(snapshot.serverNow).inMinutes
        : 0;
    final level = minutes >= 8
        ? 8
        : minutes >= 5
        ? 5
        : 0;
    final key = level == 0
        ? null
        : '${widget.orderId}:${state!.assignmentId}:$level';
    if (key == _visibleKey) return;
    _close();
    if (key == null || ref.read(_shownProvider).contains(key)) return;
    ref.read(_shownProvider.notifier).state = {
      ...ref.read(_shownProvider),
      key,
    };
    _visibleKey = key;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DepartureDialog(warning: level == 8),
    );
    _route = route;
    unawaited(
      Navigator.of(context, rootNavigator: true).push(route).then((_) {
        if (mounted && identical(_route, route)) {
          _route = null;
          _visibleKey = null;
        }
      }),
    );
  }

  @override
  void dispose() {
    final route = _route;
    _route = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.navigator != null) route!.navigator!.removeRoute(route);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enabled) ref.watch(driverMonitoringProvider(widget.orderId));
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    return widget.child;
  }
}

class _DepartureDialog extends StatelessWidget {
  const _DepartureDialog({required this.warning});
  final bool warning;
  static const title = 'Chưa ghi nhận xuất phát';

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl2),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.location_searching_rounded,
              color: warning ? AppColors.error : AppColors.warning,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              warning
                  ? DriverMonitoringStrings.warning
                  : DriverMonitoringStrings.reminder,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl2),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                minimumSize: const Size(48, 52),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                textStyle: AppTextStyles.labelLarge,
              ),
              child: const Text(DriverMonitoringStrings.acknowledge),
            ),
          ],
        ),
      ),
    ),
  );
}
