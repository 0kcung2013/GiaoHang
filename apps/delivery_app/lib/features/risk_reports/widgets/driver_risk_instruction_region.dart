import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import '../../driver/cancellation/driver_cancellation_strings.dart';
import '../../returns/data/order_return_repository.dart';
import '../../returns/driver_return_navigation_screen.dart';
import '../../returns/models/return_redelivery_result.dart';
import '../../returns/widgets/driver_return_mission_card.dart';
import '../data/risk_intervention_repository.dart';
import 'driver_risk_instruction_card.dart';
import 'driver_pending_incident_region.dart';

class DriverRiskInstructionRegion extends StatefulWidget {
  const DriverRiskInstructionRegion({
    required this.repository,
    required this.builder,
    this.order,
    this.orderId,
    this.pickupConfirmed = false,
    this.onDriverReleased,
    this.orderReturnRepository,
    this.onReturnCancelled,
    super.key,
  }) : assert(order != null || orderId != null);

  final OrderModel? order;
  final String? orderId;
  final bool pickupConfirmed;
  final Future<void> Function()? onDriverReleased;
  final RiskInterventionRepository repository;
  final OrderReturnRepository? orderReturnRepository;
  final ValueChanged<ReturnRedeliveryResult>? onReturnCancelled;
  final Widget Function(BuildContext context, bool blocksDelivery) builder;

  @override
  State<DriverRiskInstructionRegion> createState() => _RegionState();
}

class _RegionState extends State<DriverRiskInstructionRegion> {
  late Stream<RiskIntervention?> _stream;
  bool _releaseScheduled = false;

  String get _orderId => widget.order?.id ?? widget.orderId!;

  bool get _beforePickup =>
      widget.order != null &&
      const ['assigned', 'picking_up'].contains(widget.order!.status) &&
      widget.order!.actualPickedUpAt == null &&
      !widget.pickupConfirmed;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchForOrder(_orderId);
  }

  @override
  void didUpdateWidget(covariant DriverRiskInstructionRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        (oldWidget.order?.id ?? oldWidget.orderId) != _orderId) {
      _stream = widget.repository.watchForOrder(_orderId);
      _releaseScheduled = false;
    }
  }

  bool _shouldExit(RiskIntervention? intervention) =>
      _beforePickup &&
      widget.onDriverReleased != null &&
      intervention != null &&
      intervention.orderId == _orderId &&
      widget.order!.driverId != null &&
      intervention.driverId == widget.order!.driverId &&
      intervention.driverReleasedAt != null &&
      const [
        RiskInterventionState.heldBeforePickup,
        RiskInterventionState.released,
      ].contains(intervention.state);

  void _handleReturnCancelled(ReturnRedeliveryResult result) {
    if (!mounted) return;
    // RPC đã xác nhận giao lại; đọc mới can thiệp thay vì giữ snapshot cũ
    // đang khóa thanh gạt trong lúc Realtime chưa kịp gửi trạng thái mới.
    setState(() => _stream = widget.repository.watchForOrder(_orderId));
    widget.onReturnCancelled?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RiskIntervention?>(
      key: ValueKey(_stream),
      stream: _stream,
      builder: (context, snapshot) {
        final intervention = snapshot.data;
        if (_shouldExit(intervention)) {
          if (!_releaseScheduled) {
            _releaseScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _shouldExit(intervention)) {
                widget.onDriverReleased!();
              } else {
                _releaseScheduled = false;
              }
            });
          }
          return const SizedBox.shrink();
        }
        final awaitingPrePickupCancellation =
            _beforePickup &&
            intervention?.state == RiskInterventionState.handoffRequired;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (awaitingPrePickupCancellation)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  DriverCancellationStrings.supportCancellationWaiting,
                  style: AppTextStyles.bodySmall,
                ),
              )
            else if (intervention?.state ==
                    RiskInterventionState.returnRequired &&
                widget.order != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: _ReturnMissionRegion(
                  order: widget.order!,
                  onReturnCancelled: _handleReturnCancelled,
                  repository:
                      widget.orderReturnRepository ?? _createReturnRepository(),
                ),
              )
            else if (intervention != null &&
                !(_beforePickup &&
                    intervention.state == RiskInterventionState.awaitingTriage))
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: DriverRiskInstructionCard(
                  intervention: intervention,
                  onConfirmCustody: () => widget.repository
                      .confirmCustodyResolved(intervention.riskReportId),
                ),
              ),
            if (widget.order == null)
              widget.builder(
                context,
                riskInterventionBlocksDelivery(intervention),
              )
            else
              DriverPendingIncidentRegion(
                order: widget.order!,
                pickupConfirmed: widget.pickupConfirmed,
                intervention: intervention,
                builder: (context, pending) => widget.builder(
                  context,
                  pending || riskInterventionBlocksDelivery(intervention),
                ),
              ),
          ],
        );
      },
    );
  }

  OrderReturnRepository? _createReturnRepository() {
    try {
      return SupabaseOrderReturnRepository();
    } on AssertionError {
      return null;
    }
  }
}

class _ReturnMissionRegion extends StatelessWidget {
  const _ReturnMissionRegion({
    required this.order,
    this.repository,
    this.onReturnCancelled,
  });

  final OrderModel order;
  final OrderReturnRepository? repository;
  final ValueChanged<ReturnRedeliveryResult>? onReturnCancelled;

  @override
  Widget build(BuildContext context) {
    final source = repository;
    if (source == null) {
      return const DriverReturnMissionCard(mission: null, onOpen: null);
    }
    return StreamBuilder<OrderReturn?>(
      stream: source.watchForOrder(order.id),
      builder: (context, snapshot) {
        final mission = snapshot.data;
        if (mission?.status == OrderReturnStatus.cancelled) {
          return const SizedBox.shrink();
        }
        return DriverReturnMissionCard(
          mission: mission,
          onOpen: mission == null
              ? null
              : () async {
                  final result = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => DriverReturnNavigationScreen(
                        order: order,
                        mission: mission,
                        repository: source,
                      ),
                    ),
                  );
                  if (result is ReturnRedeliveryResult) {
                    onReturnCancelled?.call(result);
                  }
                },
        );
      },
    );
  }
}
