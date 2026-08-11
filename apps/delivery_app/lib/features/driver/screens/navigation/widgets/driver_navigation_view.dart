import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/services/osrm_service.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../../risk_reports/data/risk_intervention_repository.dart';
import '../../../../risk_reports/widgets/driver_risk_instruction_card.dart';
import 'driver_navigation_arrival_bar.dart';
import 'driver_risk_action.dart';

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
    this.navigationStep,
    this.maneuverDistance,
    this.totalDistance,
    this.totalDuration,
    this.onContact,
    this.riskInterventionRepository,
  });

  final OrderModel order;
  final Widget map;
  final bool arrivedAtTarget;
  final bool isUpdatingStatus;
  final VoidCallback onBack;
  final VoidCallback onFitMap;
  final VoidCallback? onPrimaryAction;
  final bool pickupConfirmed;
  final OsrmNavigationStep? navigationStep;
  final double? maneuverDistance;
  final double? totalDistance;
  final double? totalDuration;
  final VoidCallback? onContact;
  final RiskInterventionRepository? riskInterventionRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          onPressed: onBack,
                        ),
                        const Spacer(),
                        _StatusPill(
                          status: order.status,
                          pickupConfirmed: pickupConfirmed,
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
                      pickupConfirmed: pickupConfirmed,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DriverRiskAction(order: order, dark: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: riskInterventionRepository == null
                  ? _arrivalBar()
                  : DriverRiskInstructionRegion(
                      orderId: order.id,
                      repository: riskInterventionRepository!,
                      builder: (_, blocksDelivery) =>
                          _arrivalBar(blocksDelivery: blocksDelivery),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrivalBar({bool blocksDelivery = false}) {
    return DriverNavigationArrivalBar(
      order: order,
      arrivedAtTarget: arrivedAtTarget,
      pickupConfirmed: pickupConfirmed,
      isLoading: isUpdatingStatus,
      onPrimaryAction: blocksDelivery ? null : onPrimaryAction,
      onContact: onContact,
      remainingDistanceMeters: totalDistance,
      remainingDurationSeconds: totalDuration,
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
  });

  final OrderModel order;
  final OsrmNavigationStep? step;
  final double? maneuverDistance;
  final double? distance;
  final double? duration;
  final bool arrivedAtTarget;
  final bool pickupConfirmed;

  @override
  Widget build(BuildContext context) {
    final isDelivery = order.status == 'delivering';
    final fallbackTitle = isDelivery
        ? 'Đi đến điểm giao hàng'
        : 'Đi đến điểm lấy hàng';
    final title = pickupConfirmed
        ? 'Đã nhận hàng • Chờ bắt đầu giao'
        : arrivedAtTarget
        ? (isDelivery ? 'Đã đến điểm giao' : 'Đã đến điểm lấy')
        : step?.instruction ?? fallbackTitle;
    final displayedDistance = maneuverDistance ?? distance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.96),
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.textOnDark.withValues(alpha: 0.1)),
        boxShadow: AppShadow.elevated,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: AppRadius.lg,
            ),
            child: Icon(
              arrivedAtTarget
                  ? Icons.location_on_rounded
                  : _maneuverIcon(step?.modifier),
              color: AppColors.textOnAccent,
              size: 29,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      pickupConfirmed
                          ? 'GPS đang tạm dừng'
                          : displayedDistance == null
                          ? 'Đang tải lộ trình...'
                          : 'Còn ${DeliveryMapUtils.formatDistance(displayedDistance)}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textOnDark.withValues(alpha: 0.8),
                      ),
                    ),
                    if (!pickupConfirmed && duration != null) ...[
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
                          color: AppColors.textOnDark.withValues(alpha: 0.8),
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
    final label = pickupConfirmed
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
