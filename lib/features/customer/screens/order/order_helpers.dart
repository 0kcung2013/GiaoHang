part of 'order_screen.dart';

class _TimelineStep {
  final String title;
  final String? description;
  final String time;
  final String status;

  const _TimelineStep({
    required this.title,
    required this.description,
    required this.time,
    required this.status,
  });
}

List<_TimelineStep> _fallbackTimelineSteps(OrderModel order) {
  final statusView = _OrderStatusView.fromStatus(order.status);
  final createdTime = _formatOrderDateTime(order.createdAt);
  final updatedTime = order.updatedAt.millisecondsSinceEpoch > 0
      ? _formatOrderDateTime(order.updatedAt)
      : createdTime;

  if (order.status == 'pending') {
    return [
      _TimelineStep(
        title: statusView.label,
        description: 'Đơn hàng đã được tạo và đang chờ xác nhận.',
        time: createdTime,
        status: order.status,
      ),
    ];
  }

  return [
    _TimelineStep(
      title: 'Đã tạo đơn',
      description: 'Đơn hàng đã được ghi nhận trong hệ thống.',
      time: createdTime,
      status: 'pending',
    ),
    _TimelineStep(
      title: statusView.label,
      description: order.status == 'cancelled'
          ? (order.statusNote?.trim().isNotEmpty ?? false
                ? order.statusNote!.trim()
                : 'Đơn hàng đã bị huỷ.')
          : _statusProgressDescription(order.status),
      time: updatedTime,
      status: order.status,
    ),
  ];
}

String _statusProgressDescription(String status) {
  return switch (status) {
    'confirmed' => 'Đơn hàng đã được xác nhận.',
    'assigned' => 'Tài xế đã nhận đơn và chuẩn bị đến điểm lấy hàng.',
    'picking_up' => 'Tài xế đang đến điểm lấy hàng.',
    'delivering' => 'Đơn hàng đang trên đường giao đến bạn.',
    'delivered' => 'Đơn hàng đã được giao thành công.',
    _ => 'Cập nhật gần nhất của đơn hàng.',
  };
}

String _formatOrderDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final hour = twoDigits(value.hour);
  final minute = twoDigits(value.minute);
  final day = twoDigits(value.day);
  final month = twoDigits(value.month);
  return '$hour:$minute · $day/$month/${value.year}';
}

class _OrderStatusView {
  final String label;
  final Color color;
  final IconData icon;

  const _OrderStatusView({
    required this.label,
    required this.color,
    required this.icon,
  });

  factory _OrderStatusView.fromStatus(String status) {
    return switch (status) {
      'pending' => const _OrderStatusView(
        label: 'Chờ xác nhận',
        color: AppColors.warning,
        icon: Icons.access_time_rounded,
      ),
      'confirmed' => const _OrderStatusView(
        label: 'Đã xác nhận',
        color: AppColors.info,
        icon: Icons.check_circle_rounded,
      ),
      'assigned' => const _OrderStatusView(
        label: 'Tài xế đã nhận đơn',
        color: AppColors.info,
        icon: Icons.local_shipping_rounded,
      ),
      'picking_up' => const _OrderStatusView(
        label: 'Tài xế đang đến lấy hàng',
        color: AppColors.accent,
        icon: Icons.inventory_2_rounded,
      ),
      'delivering' => const _OrderStatusView(
        label: 'Đang giao hàng',
        color: AppColors.accent,
        icon: Icons.local_shipping_rounded,
      ),
      'delivered' => const _OrderStatusView(
        label: 'Giao hàng thành công',
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      ),
      'cancelled' => const _OrderStatusView(
        label: 'Huỷ',
        color: AppColors.error,
        icon: Icons.cancel_rounded,
      ),
      _ => const _OrderStatusView(
        label: 'Không rõ',
        color: AppColors.textMuted,
        icon: Icons.help_outline_rounded,
      ),
    };
  }
}
