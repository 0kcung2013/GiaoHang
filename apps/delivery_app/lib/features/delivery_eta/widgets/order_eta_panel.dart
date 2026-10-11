import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../core/models/order_model.dart';
import '../models/order_eta.dart';
import '../order_eta_providers.dart';
import '../order_eta_strings.dart';

class OrderEtaPanel extends ConsumerStatefulWidget {
  const OrderEtaPanel({
    super.key,
    required this.order,
    this.showDetails = true,
  });
  final OrderModel order;
  final bool showDetails;
  @override
  ConsumerState<OrderEtaPanel> createState() => _OrderEtaPanelState();
}

class _OrderEtaPanelState extends ConsumerState<OrderEtaPanel> {
  Timer? _timer;
  bool _expanded = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrderEtaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.order, next = widget.order;
    if (old.id == next.id && old.driverId != next.driverId) {
      Future.microtask(() {
        if (mounted) ref.invalidate(orderEtaProvider(next.id));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final active =
        order.driverId != null &&
        const {'assigned', 'picking_up', 'delivering'}.contains(order.status);
    if (!active && !const {'pending', 'confirmed'}.contains(order.status)) {
      return const SizedBox.shrink();
    }
    final response = active
        ? ref.watch(orderEtaProvider(order.id)).valueOrNull
        : null;
    final eta =
        response?.data == null ||
            (response?.data?['driver_id'] == order.driverId &&
                response?.isFixed == true)
        ? response
        : null;
    final now = DateTime.now();
    final predicted = eta?.predictedAt;
    final local = predicted == null ? null : VietnamTime.toWallClock(predicted);
    String two(int n) => n.toString().padLeft(2, '0');
    final title = !active
        ? OrderEtaStrings.waiting
        : eta?.hasEstimate != true
        ? eta?.issue != null
              ? OrderEtaStrings.unavailable
              : OrderEtaStrings.calculating
        : OrderEtaStrings.predicted;
    final subtitle = !active
        ? null
        : eta?.hasEstimate != true
        ? eta?.issue != null
              ? OrderEtaStrings.retrying
              : null
        : eta!.staleAt(now)
        ? OrderEtaStrings.stale
        : eta.remainingAt(now) == 0
        ? OrderEtaStrings.delayed
        : OrderEtaStrings.remaining(eta.remainingAt(now));
    return Container(
      key: const ValueKey('order-eta-panel'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.bgWarm,
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.accent,
                size: 21,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTextStyles.labelMedium)),
              if (local != null)
                Text(
                  '${two(local.hour)}:${two(local.minute)}',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (widget.showDetails && eta?.hasEstimate == true) ...[
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size(48, 48),
              ),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
              ),
              label: const Text(OrderEtaStrings.details),
            ),
            if (_expanded) _EtaDetails(eta: eta!),
          ],
        ],
      ),
    );
  }
}

class _EtaDetails extends StatelessWidget {
  const _EtaDetails({required this.eta});
  final OrderEta eta;
  @override
  Widget build(BuildContext context) {
    final rows = <String, double>{
      if (eta.number('preparation_minutes') > 0)
        OrderEtaStrings.prepare: eta.number('preparation_minutes'),
      if (eta.data?['approach'] != null)
        OrderEtaStrings.approach:
            (eta.data!['approach']['travel_minutes'] as num).toDouble(),
      if (eta.number('pickup_minutes') > 0)
        OrderEtaStrings.pickupHandling: eta.number('pickup_minutes'),
      if (eta.data?['delivery'] != null)
        OrderEtaStrings.delivery:
            (eta.data!['delivery']['travel_minutes'] as num).toDouble(),
      if (eta.number('handoff_minutes') > 0)
        OrderEtaStrings.deliveryHandling: eta.number('handoff_minutes'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(OrderEtaStrings.initialEstimate, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        for (final row in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(child: Text(row.key, style: AppTextStyles.bodySmall)),
                Text(
                  OrderEtaStrings.minutes(row.value),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          !eta.usesAi
              ? OrderEtaStrings.baseline
              : eta.isSynthetic
              ? OrderEtaStrings.simulated
              : OrderEtaStrings.historical,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (eta.number('preparation_removed_minutes') == 5) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            OrderEtaStrings.preparationRemoved,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ],
    );
  }
}
