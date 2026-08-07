import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'driver_arrival_policy.dart';

enum DriverDeliveryAction {
  startPickupJourney,
  confirmPickup,
  startDelivery,
  confirmDelivery,
  none,
}

extension DriverDeliveryActionRules on DriverDeliveryAction {
  bool get requiresProofPhoto =>
      this == DriverDeliveryAction.confirmPickup ||
      this == DriverDeliveryAction.confirmDelivery;

  bool get advancesOrderStatusImmediately => this != DriverDeliveryAction.none;
}

class DriverDeliveryWorkflow {
  const DriverDeliveryWorkflow({
    required this.stepIndex,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.accent,
    required this.action,
    required this.requiresArrival,
  });

  final int stepIndex;
  final String eyebrow;
  final String title;
  final String description;
  final String primaryLabel;
  final IconData primaryIcon;
  final Color accent;
  final DriverDeliveryAction action;
  final bool requiresArrival;

  static const double arrivalRadiusMeters =
      DriverArrivalPolicy.arrivalRadiusMeters;

  bool canPerform({required bool arrivedAtTarget}) {
    return action != DriverDeliveryAction.none &&
        (!requiresArrival || arrivedAtTarget);
  }

  static DriverDeliveryWorkflow fromStatus(
    String status, {
    bool pickupConfirmed = false,
  }) {
    if (status == 'picking_up' && pickupConfirmed) {
      return const DriverDeliveryWorkflow(
        stepIndex: 2,
        eyebrow: 'CHỜ BẮT ĐẦU GIAO',
        title: 'Đã nhận hàng',
        description: 'GPS đang tạm dừng. Bắt đầu khi bạn sẵn sàng.',
        primaryLabel: 'Bắt đầu giao hàng',
        primaryIcon: Icons.local_shipping_rounded,
        accent: AppColors.accent,
        action: DriverDeliveryAction.startDelivery,
        requiresArrival: false,
      );
    }

    return switch (status) {
      'assigned' => const DriverDeliveryWorkflow(
        stepIndex: 0,
        eyebrow: 'ĐƠN ĐÃ ĐƯỢC NHẬN',
        title: 'Sẵn sàng đến điểm lấy',
        description:
            'Kiểm tra thông tin đơn và bắt đầu hành trình khi bạn đã sẵn sàng.',
        primaryLabel: 'Bắt đầu đến điểm lấy',
        primaryIcon: Icons.navigation_rounded,
        accent: AppColors.accent,
        action: DriverDeliveryAction.startPickupJourney,
        requiresArrival: false,
      ),
      'picking_up' => const DriverDeliveryWorkflow(
        stepIndex: 1,
        eyebrow: 'CHẶNG LẤY HÀNG',
        title: 'Di chuyển đến người gửi',
        description:
            'Chỉ xác nhận nhận hàng sau khi đã kiểm tra đúng kiện và tình trạng.',
        primaryLabel: 'Xác nhận đã nhận hàng',
        primaryIcon: Icons.inventory_2_rounded,
        accent: AppColors.markerPickup,
        action: DriverDeliveryAction.confirmPickup,
        requiresArrival: true,
      ),
      'delivering' => const DriverDeliveryWorkflow(
        stepIndex: 2,
        eyebrow: 'CHẶNG GIAO HÀNG',
        title: 'Giao hàng đến người nhận',
        description:
            'Đối chiếu người nhận và thanh toán trước khi hoàn tất đơn.',
        primaryLabel: 'Xác nhận giao thành công',
        primaryIcon: Icons.check_circle_rounded,
        accent: AppColors.success,
        action: DriverDeliveryAction.confirmDelivery,
        requiresArrival: true,
      ),
      'delivered' => const DriverDeliveryWorkflow(
        stepIndex: 3,
        eyebrow: 'ĐÃ HOÀN THÀNH',
        title: 'Giao hàng thành công',
        description: 'Đơn hàng đã được bàn giao và ghi nhận hoàn tất.',
        primaryLabel: 'Đã hoàn tất',
        primaryIcon: Icons.verified_rounded,
        accent: AppColors.success,
        action: DriverDeliveryAction.none,
        requiresArrival: false,
      ),
      _ => const DriverDeliveryWorkflow(
        stepIndex: 0,
        eyebrow: 'TRẠNG THÁI ĐƠN',
        title: 'Đang chờ cập nhật',
        description: 'Vui lòng tải lại đơn hàng để tiếp tục.',
        primaryLabel: 'Chưa thể thao tác',
        primaryIcon: Icons.sync_problem_rounded,
        accent: AppColors.textMuted,
        action: DriverDeliveryAction.none,
        requiresArrival: false,
      ),
    };
  }

  static bool canSimulateMovement({
    required String status,
    required bool pickupConfirmed,
    required bool arrivedAtTarget,
  }) {
    if (arrivedAtTarget || pickupConfirmed) return false;
    return status == 'picking_up' || status == 'delivering';
  }
}
