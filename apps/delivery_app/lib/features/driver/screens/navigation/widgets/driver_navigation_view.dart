import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/services/osrm_service.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../../risk_reports/data/risk_intervention_repository.dart';
import '../../../../risk_reports/data/participant_risk_report_query_repository.dart';
import '../../../../risk_reports/widgets/driver_risk_instruction_card.dart';
import '../../../../order_contact/widgets/driver_incoming_message_alert.dart';
import '../models/driver_delivery_workflow.dart';
import '../utils/driver_delivery_arrival_strings.dart';
import 'driver_help_actions.dart';
import 'driver_navigation_arrival_bar.dart';
import 'driver_delivery_arrival_region.dart';
import '../models/driver_delivery_arrival.dart';
import '../data/driver_delivery_arrival_repository.dart';
import 'driver_recipient_wait_region.dart';
import 'driver_order_details_layout.dart';
import '../../../cancellation/widgets/driver_cancel_order_action.dart';

class DriverNavigationView extends StatelessWidget {
  const DriverNavigationView({
    super.key,
    required this.order,
    required this.map,
    required this.arrivedAtTarget,
    required this.isUpdatingStatus,
    required this.onBack,
    required this.onFitMap,
    required this.onPrimaryAction,
    this.pickupConfirmed = false,
    this.routeCompleted = false,
    this.navigationStep,
    this.maneuverDistance,
    this.totalDistance,
    this.totalDuration,
    this.driverLatitude,
    this.driverLongitude,
    this.onContact,
    this.currentUserId,
    this.onOpenMessageChat,
    this.riskInterventionRepository,
    this.onConfirmPickupArrival,
    this.onPrepareDeliveryArrival,
    this.onReportRecipient,
    this.deliveryArrivalRepository,
    this.recipientReportsRepository,
    this.onDriverReleased,
    this.showOrderDetails = false,
    this.onOrderCancelled,
  });

  final OrderModel order;
  final Widget map;
  final bool arrivedAtTarget;
  final bool isUpdatingStatus;
  final VoidCallback onBack;
  final VoidCallback onFitMap;
  final VoidCallback? onPrimaryAction;
  final bool pickupConfirmed;
  final bool routeCompleted;
  final OsrmNavigationStep? navigationStep;
  final double? maneuverDistance;
  final double? totalDistance;
  final double? totalDuration;
  final double? driverLatitude;
  final double? driverLongitude;
  final VoidCallback? onContact;
  final String? currentUserId;
  final Future<void> Function()? onOpenMessageChat;
  final RiskInterventionRepository? riskInterventionRepository;
  final VoidCallback? onConfirmPickupArrival;
  final Future<void> Function()? onPrepareDeliveryArrival;
  final VoidCallback? onReportRecipient;
  final DriverDeliveryArrivalRepository? deliveryArrivalRepository;
  final ParticipantRiskReportQueryRepository? recipientReportsRepository;
  final Future<void> Function()? onDriverReleased;
  final bool showOrderDetails;
  final VoidCallback? onOrderCancelled;

  @override
  Widget build(BuildContext context) {
    final workflow = DriverDeliveryWorkflow.fromStatus(
      order.status,
      pickupConfirmed: pickupConfirmed,
    );
    Widget buildMap(VoidCallback back, {bool includeFooter = true}) => Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          map,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _MapControlButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Quay lại',
                          onPressed: back,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _StatusPill(
                              status: order.status,
                              pickupConfirmed: pickupConfirmed,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DriverHelpActions(
                          order: order,
                          initialLatitude: driverLatitude,
                          initialLongitude: driverLongitude,
                          dark: true,
                          collapsed: true,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _MapControlButton(
                          icon: Icons.my_location_rounded,
                          tooltip: 'Theo vị trí',
                          onPressed: onFitMap,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _NavigationInstructionCard(
                      order: order,
                      step: navigationStep,
                      maneuverDistance: maneuverDistance,
                      distance: totalDistance,
                      duration: totalDuration,
                      arrivedAtTarget: arrivedAtTarget,
                      routeCompleted: routeCompleted,
                      pickupConfirmed: pickupConfirmed,
                    ),
                    if (workflow.allowsContactChat &&
                        currentUserId != null &&
                        onOpenMessageChat != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DriverIncomingMessageAlert(
                          orderId: order.id,
                          currentUserId: currentUserId!,
                          onOpenChat: onOpenMessageChat!,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (includeFooter)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _footer()),
            ),
        ],
      ),
    );
    final view = showOrderDetails
        ? DriverOrderDetailsLayout(
            order: order,
            onBack: onBack,
            mapBuilder: (back) => buildMap(back, includeFooter: false),
            footer: _footer(),
            cancellationAction: DriverCancelOrderAction(
              order: order,
              pickupConfirmed: pickupConfirmed,
              onCancelled: onOrderCancelled,
            ),
            status: _StatusPill(
              status: order.status,
              pickupConfirmed: pickupConfirmed,
            ),
            notice: routeCompleted
                ? Text(
                    DriverDeliveryArrivalStrings.simulationStopped,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
            helpAction: DriverHelpActions(
              order: order,
              initialLatitude: driverLatitude,
              initialLongitude: driverLongitude,
              collapsed: true,
            ),
          )
        : buildMap(onBack);
    if (recipientReportsRepository == null ||
        riskInterventionRepository == null) {
      return view;
    }
    return DriverRecipientWaitRegion(
      key: ValueKey('recipient-wait-${order.id}'),
      order: order,
      reports: recipientReportsRepository!,
      interventions: riskInterventionRepository!,
      arrivalRepository: deliveryArrivalRepository,
      child: view,
    );
  }

  Widget _footer() => riskInterventionRepository == null
      ? _arrivalBar()
      : DriverRiskInstructionRegion(
          order: order,
          pickupConfirmed: pickupConfirmed,
          onDriverReleased: onDriverReleased,
          repository: riskInterventionRepository!,
          builder: (_, blocksDelivery) =>
              _arrivalBar(blocksDelivery: blocksDelivery),
        );

  Widget _arrivalBar({bool blocksDelivery = false}) {
    if (order.status == 'delivering' && onPrepareDeliveryArrival != null) {
      return DriverDeliveryArrivalRegion(
        key: ValueKey('delivery-arrival-${order.id}'),
        orderId: order.id,
        beforeConfirm: onPrepareDeliveryArrival,
        repository: deliveryArrivalRepository,
        builder: (arrival, elapsed, loading, error, confirm, retry) =>
            _buildArrivalBar(
              blocksDelivery: blocksDelivery,
              deliveryArrival: arrival,
              deliveryWait: elapsed,
              arrivalLoading: loading,
              arrivalError: error,
              onConfirmDeliveryArrival: confirm,
              onRetryArrival: retry,
            ),
      );
    }
    return _buildArrivalBar(blocksDelivery: blocksDelivery);
  }

  Widget _buildArrivalBar({
    bool blocksDelivery = false,
    DriverDeliveryArrival? deliveryArrival,
    Duration? deliveryWait,
    bool arrivalLoading = false,
    String? arrivalError,
    VoidCallback? onConfirmDeliveryArrival,
    VoidCallback? onRetryArrival,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DriverNavigationArrivalBar(
          order: order,
          arrivedAtTarget: arrivedAtTarget,
          pickupConfirmed: pickupConfirmed,
          isLoading: isUpdatingStatus || arrivalLoading,
          onPrimaryAction: blocksDelivery ? null : onPrimaryAction,
          onContact: onContact,
          remainingDistanceMeters: totalDistance,
          remainingDurationSeconds: totalDuration,
          onConfirmPickupArrival: blocksDelivery
              ? null
              : onConfirmPickupArrival,
          deliveryArrival: deliveryArrival,
          deliveryWait: deliveryWait,
          arrivalError: arrivalError,
          onRetryArrival: onRetryArrival,
          onConfirmDeliveryArrival: blocksDelivery
              ? null
              : onConfirmDeliveryArrival,
          onReportRecipient: blocksDelivery ? null : onReportRecipient,
        ),
      ],
    );
  }
}

class _NavigationInstructionCard extends StatelessWidget {
  const _NavigationInstructionCard({
    required this.order,
    required this.step,
    required this.maneuverDistance,
    required this.distance,
    required this.duration,
    required this.arrivedAtTarget,
    required this.pickupConfirmed,
    required this.routeCompleted,
  });

  final OrderModel order;
  final OsrmNavigationStep? step;
  final double? maneuverDistance;
  final double? distance;
  final double? duration;
  final bool arrivedAtTarget;
  final bool pickupConfirmed;
  final bool routeCompleted;

  @override
  Widget build(BuildContext context) {
    final isDelivery = order.status == 'delivering';
    final waitingToStartDelivery =
        order.status == 'picking_up' && pickupConfirmed;
    final fallbackTitle = isDelivery
        ? 'Đi đến điểm giao hàng'
        : 'Đi đến điểm lấy hàng';
    final title = waitingToStartDelivery
        ? 'Đã nhận hàng • Chờ bắt đầu giao'
        : arrivedAtTarget
        ? (isDelivery ? 'Đã đến điểm giao' : 'Đã đến điểm lấy')
        : step?.instruction ?? fallbackTitle;
    final displayedDistance = maneuverDistance ?? distance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: AppRadius.md,
            ),
            child: Icon(
              arrivedAtTarget
                  ? Icons.location_on_rounded
                  : _maneuverIcon(step?.modifier),
              color: AppColors.textOnAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      routeCompleted
                          ? DriverDeliveryArrivalStrings.simulationStopped
                          : waitingToStartDelivery
                          ? 'GPS đang tạm dừng'
                          : displayedDistance == null
                          ? 'Đang tải lộ trình...'
                          : 'Còn ${DeliveryMapUtils.formatDistance(displayedDistance)}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!routeCompleted &&
                        !waitingToStartDelivery &&
                        duration != null) ...[
                      Container(
                        width: 3,
                        height: 3,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        DeliveryMapUtils.formatDuration(duration!),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _maneuverIcon(String? modifier) {
    return switch (modifier) {
      'left' || 'slight left' || 'sharp left' => Icons.turn_left_rounded,
      'right' || 'slight right' || 'sharp right' => Icons.turn_right_rounded,
      'uturn' => Icons.u_turn_left_rounded,
      _ => Icons.straight_rounded,
    };
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: AppRadius.full,
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.2),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.pickupConfirmed});

  final String status;
  final bool pickupConfirmed;

  @override
  Widget build(BuildContext context) {
    final label = status == 'picking_up' && pickupConfirmed
        ? 'Chờ bắt đầu giao'
        : switch (status) {
            'assigned' => 'Đã nhận đơn',
            'picking_up' => 'Đang lấy hàng',
            'delivering' => 'Đang giao hàng',
            'delivered' => 'Hoàn tất',
            'risk_hold' => 'Tạm giữ xử lý sự cố',
            _ => 'Đang cập nhật',
          };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.full,
        boxShadow: AppShadow.card,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
