import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/models/order_model.dart';

export '../../../risk_reports/widgets/customer_tracking_risk_action.dart'
    show CustomerTrackingRiskAction;

class TimelineStep {
  const TimelineStep({
    required this.title,
    required this.description,
    required this.time,
    required this.status,
  });

  final String title;
  final String? description;
  final String time;
  final String status;
}

List<TimelineStep> fallbackTimelineSteps(OrderModel order) {
  final effectiveStatus = order.effectiveStatusAt(DateTime.now());
  final statusView = OrderStatusView.fromStatus(effectiveStatus);
  final createdTime = formatOrderDateTime(order.createdAt);
  final updatedTime = order.updatedAt.millisecondsSinceEpoch > 0
      ? formatOrderDateTime(order.updatedAt)
      : createdTime;

  if (effectiveStatus == 'assignment_timeout') {
    return [
      TimelineStep(
        title: 'Đã tạo đơn',
        description: 'Đơn hàng đã được ghi nhận trong hệ thống.',
        time: createdTime,
        status: 'pending',
      ),
      TimelineStep(
        title: statusView.label,
        description: 'Chưa có tài xế nhận đơn trong vòng 15 phút.',
        time: formatOrderDateTime(order.assignmentDeadline),
        status: effectiveStatus,
      ),
    ];
  }

  if (order.status == 'pending') {
    return [
      TimelineStep(
        title: statusView.label,
        description: 'Đơn hàng đã được tạo và đang chờ xác nhận.',
        time: createdTime,
        status: order.status,
      ),
    ];
  }

  return [
    TimelineStep(
      title: 'Đã tạo đơn',
      description: 'Đơn hàng đã được ghi nhận trong hệ thống.',
      time: createdTime,
      status: 'pending',
    ),
    TimelineStep(
      title: statusView.label,
      description: order.status == 'cancelled'
          ? (order.statusNote?.trim().isNotEmpty ?? false
                ? order.statusNote!.trim()
                : 'Đơn hàng đã bị hủy.')
          : statusProgressDescription(order.status),
      time: updatedTime,
      status: order.status,
    ),
  ];
}

String statusProgressDescription(String status) {
  return switch (status) {
    'confirmed' => 'Đơn hàng đã được xác nhận.',
    'assigned' => 'Tài xế đã nhận đơn và chuẩn bị đến điểm lấy hàng.',
    'picking_up' => 'Tài xế đang đến điểm lấy hàng.',
    'delivering' => 'Đơn hàng đang trên đường giao đến bạn.',
    'delivered' => 'Đơn hàng đã được giao thành công.',
    'risk_hold' => 'Đơn hàng đang tạm giữ để CSKH xử lý sự cố.',
    _ => 'Cập nhật gần nhất của đơn hàng.',
  };
}

bool shouldShowAssignedDriverForOrder(OrderModel order) {
  final driverId = order.driverId?.trim();
  if (driverId != null && driverId.isNotEmpty) return true;

  return switch (order.status) {
    'assigned' || 'picking_up' || 'delivering' || 'delivered' => true,
    _ => false,
  };
}

String formatOrderDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final hour = twoDigits(value.hour);
  final minute = twoDigits(value.minute);
  final day = twoDigits(value.day);
  final month = twoDigits(value.month);
  return '$hour:$minute · $day/$month/${value.year}';
}

class OrderStatusView {
  const OrderStatusView({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  factory OrderStatusView.fromStatus(String status) {
    return switch (status) {
      'pending' => const OrderStatusView(
        label: 'Chờ xác nhận',
        color: AppColors.warning,
        icon: Icons.access_time_rounded,
      ),
      'confirmed' => const OrderStatusView(
        label: 'Đã xác nhận',
        color: AppColors.info,
        icon: Icons.check_circle_rounded,
      ),
      'assigned' => const OrderStatusView(
        label: 'Đã có tài xế',
        color: AppColors.info,
        icon: Icons.local_shipping_rounded,
      ),
      'picking_up' => const OrderStatusView(
        label: 'Đang lấy hàng',
        color: AppColors.accent,
        icon: Icons.inventory_2_rounded,
      ),
      'delivering' => const OrderStatusView(
        label: 'Đang giao',
        color: AppColors.accent,
        icon: Icons.local_shipping_rounded,
      ),
      'risk_hold' => const OrderStatusView(
        label: 'Tạm giữ xử lý sự cố',
        color: AppColors.warning,
        icon: Icons.pause_circle_outline_rounded,
      ),
      'delivered' => const OrderStatusView(
        label: 'Hoàn thành',
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      ),
      'cancelled' => const OrderStatusView(
        label: 'Đã hủy',
        color: AppColors.error,
        icon: Icons.cancel_rounded,
      ),
      'assignment_timeout' => const OrderStatusView(
        label: 'Chưa có tài xế',
        color: AppColors.error,
        icon: Icons.person_search_rounded,
      ),
      _ => const OrderStatusView(
        label: 'Không rõ',
        color: AppColors.textMuted,
        icon: Icons.help_outline_rounded,
      ),
    };
  }
}
