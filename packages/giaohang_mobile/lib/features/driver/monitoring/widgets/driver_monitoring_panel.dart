import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../driver_monitoring_providers.dart';

class DriverMonitoringPanel extends ConsumerWidget {
  const DriverMonitoringPanel({
    required this.orderId,
    required this.holdingGoods,
    required this.onRecover,
    this.pickupArrivedAt,
    super.key,
  });
  final String orderId;
  final bool holdingGoods;
  final Future<void> Function() onRecover;
  final DateTime? pickupArrivedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(driverMonitoringProvider(orderId));
    final snapshot = value.valueOrNull;
    return DriverMonitoringStatusCard(
      state: snapshot?.state,
      serverNow: snapshot?.serverNow,
      holdingGoods: holdingGoods,
      pickupArrivedAt: pickupArrivedAt,
      error: value.hasError,
      onRecover: onRecover,
    );
  }
}

/// UI thuần để kiểm tra nội dung, màn hình nhỏ và cỡ chữ lớn độc lập với mạng.
class DriverMonitoringStatusCard extends StatefulWidget {
  const DriverMonitoringStatusCard({
    required this.state,
    required this.serverNow,
    required this.holdingGoods,
    required this.onRecover,
    this.pickupArrivedAt,
    this.error = false,
    super.key,
  });
  final DriverMonitoring? state;
  final DateTime? serverNow;
  final bool holdingGoods;
  final bool error;
  final Future<void> Function() onRecover;
  final DateTime? pickupArrivedAt;
  @override
  State<DriverMonitoringStatusCard> createState() =>
      _DriverMonitoringStatusCardState();
}

class _DriverMonitoringStatusCardState
    extends State<DriverMonitoringStatusCard> {
  bool _recovering = false;
  bool _recoveryFailed = false;
  Future<void> _recover() async {
    setState(() {
      _recovering = true;
      _recoveryFailed = false;
    });
    try {
      await widget.onRecover();
    } catch (_) {
      if (mounted) setState(() => _recoveryFailed = true);
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final now = widget.serverNow;
    final missing =
        widget.error ||
        (state != null && now != null && state.gpsMissingAt(now));
    final elapsed = state != null && now != null
        ? state.elapsedAt(now)
        : Duration.zero;
    final arrived = widget.pickupArrivedAt;
    final confirmedArrival =
        arrived != null && state != null && !arrived.isBefore(state.acceptedAt);
    final waiting =
        !widget.holdingGoods && (state?.atPickupAt != null || confirmedArrival);
    final warning =
        !widget.holdingGoods &&
        !waiting &&
        state != null &&
        !state.hasStarted &&
        elapsed >= const Duration(minutes: 8);
    final message = widget.error
        ? DriverMonitoringStrings.loadError
        : state == null
        ? DriverMonitoringStrings.syncing
        : missing
        ? widget.holdingGoods
              ? DriverMonitoringStrings.custodyWarning
              : DriverMonitoringStrings.gpsWarning
        : waiting
        ? DriverMonitoringStrings.waitingPickup
        : widget.holdingGoods || state.hasStarted
        ? null
        : warning
        ? DriverMonitoringStrings.warning
        : elapsed >= const Duration(minutes: 5)
        ? DriverMonitoringStrings.reminder
        : DriverMonitoringStrings.preparing;
    final color = missing || warning ? AppColors.warning : AppColors.success;
    return Container(
      key: const Key('driver-monitoring-status'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                missing
                    ? Icons.location_off_outlined
                    : Icons.location_searching_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  missing
                      ? DriverMonitoringStrings.missing
                      : DriverMonitoringStrings.active,
                  style: AppTextStyles.labelMedium,
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (_recoveryFailed) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              DriverMonitoringStrings.recoveryError,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          if (missing || _recoveryFailed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _recovering ? null : _recover,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(
                  _recovering
                      ? DriverMonitoringStrings.syncing
                      : DriverMonitoringStrings.recover,
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
