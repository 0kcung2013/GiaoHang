import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show VietnamTime;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/order_model.dart';
import '../../../core/location/driver_workload_policy.dart';
import '../../../core/location/driver_location_producer_policy.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/location_providers.dart';
import '../../../core/providers/driver_nav_session_provider.dart';
import '../../../core/providers/driver_task_priority_provider.dart';
import '../cancellation/driver_cancellation_providers.dart';
import '../screens/navigation/driver_navigation_screen.dart';
import 'recipient_hold_repository.dart';
import 'recipient_hold_strings.dart';

class DriverHeldOrderCard extends ConsumerStatefulWidget {
  const DriverHeldOrderCard({super.key, required this.order});
  final OrderModel order;
  @override
  ConsumerState<DriverHeldOrderCard> createState() =>
      _DriverHeldOrderCardState();
}

class _DriverHeldOrderCardState extends ConsumerState<DriverHeldOrderCard> {
  Timer? timer;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _act({bool requestReturn = false}) async {
    if (busy) return;
    setState(() => busy = true);
    final order = widget.order;
    try {
      if (requestReturn) {
        // Synchronize a fresh physical fix; the server checks time and geofence.
        final mode = ref.read(driverLocationModeProvider);
        final pos = await ref
            .read(locationServiceProvider)
            .getCurrentPosition();
        final shared = ref.read(driverPhysicalPositionProvider);
        if (mode == DriverLocationMode.deviceGps && pos == null) {
          throw StateError('GPS_REQUIRED');
        }
        final lat = mode == DriverLocationMode.deviceGps
            ? pos!.latitude
            : shared?.latitude;
        final lng = mode == DriverLocationMode.deviceGps
            ? pos!.longitude
            : shared?.longitude;
        if (lat == null || lng == null) throw StateError('GPS_REQUIRED');
        await ref
            .read(locationIngestServiceProvider)
            .ingest(
              driverUserId: order.driverId,
              orderId: order.id,
              lat: lat,
              lng: lng,
              force: true,
              accuracy: mode == DriverLocationMode.deviceGps
                  ? pos!.accuracy
                  : 0,
              capturedAt: mode == DriverLocationMode.deviceGps
                  ? pos!.timestamp
                  : DateTime.now(),
              coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
            );
        await ref.read(recipientHoldRepositoryProvider).requestReturn(order.id);
      } else {
        final resumed = await ref
            .read(recipientHoldRepositoryProvider)
            .update(order.id);
        await ref.read(driverNavSessionsProvider.notifier).remove(order.id);
        if (!mounted) return;
        ref.read(driverPriorityOrderIdProvider.notifier).state = order.id;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DriverNavigationScreen(order: resumed),
          ),
        );
      }
      ref.invalidate(driverOrdersProvider(order.driverId!));
      ref.invalidate(availableOrdersProvider(order.driverId!));
      if (requestReturn && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(RecipientHoldStrings.returnSent)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$error'.contains('HOLD_OTHER_ORDER_ACTIVE')
                  ? RecipientHoldStrings.otherOrder
                  : RecipientHoldStrings.failed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final h = o.recipientHold!;
    final now =
        ref
            .watch(driverAcceptanceStateProvider(o.driverId!))
            .valueOrNull
            ?.now() ??
        DateTime.now();
    final left = h.until.difference(now);
    final due = !left.isNegative
        ? 'Còn ${(left.inSeconds / 60).ceil()} phút'
        : RecipientHoldStrings.due;
    final local = VietnamTime.toWallClock(h.until);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final other =
        ref
            .watch(driverOrdersProvider(o.driverId!))
            .valueOrNull
            ?.any((x) => x.id != o.id && DriverWorkloadPolicy.isWorking(x)) ??
        true;
    final returnReady = !now.isBefore(h.returnEligibleAt) && !other;
    return Container(
      key: const ValueKey('held-order-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.warning.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pause_circle_outline_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  RecipientHoldStrings.holding,
                  style: AppTextStyles.labelLarge,
                ),
              ),
              Text(o.trackingCode, style: AppTextStyles.mono),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            o.deliveryAddress,
            style: AppTextStyles.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hẹn $time · $due',
            style: AppTextStyles.labelMedium.copyWith(
              color: left.isNegative
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (h.returnRequested)
            Text(
              RecipientHoldStrings.returnSent,
              style: AppTextStyles.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(48, 48),
                    textStyle: AppTextStyles.labelMedium,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                  onPressed: busy ? null : () => _act(),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text(RecipientHoldStrings.resume),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.info,
                    minimumSize: const Size(48, 48),
                    textStyle: AppTextStyles.labelMedium,
                  ),
                  onPressed: o.recipientPhone == null
                      ? null
                      : () => launchUrl(
                          Uri(scheme: 'tel', path: o.recipientPhone),
                        ),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Gọi khách'),
                ),
                if (returnReady)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(48, 48),
                      textStyle: AppTextStyles.labelMedium,
                    ),
                    onPressed: busy ? null : () => _act(requestReturn: true),
                    child: const Text(RecipientHoldStrings.returnAction),
                  ),
              ],
            ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
