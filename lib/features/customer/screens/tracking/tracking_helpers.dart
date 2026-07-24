part of 'tracking_screen.dart';

class _TimelineStep {
  final String title;
  final String time;
  final String description;
  final bool done;

  const _TimelineStep({
    required this.title,
    required this.time,
    required this.description,
    required this.done,
  });
}

List<_TimelineStep> _fallbackTimelineSteps(OrderModel order) {
  return _timelineSteps(order, const []);
}

List<_TimelineStep> _timelineSteps(
  OrderModel order,
  List<OrderStatusLogModel> logs,
) {
  final logsByStatus = _latestLogByStatus(logs);
  final statusIndex = _statusOrder.indexOf(order.status);
  if (order.status == 'cancelled') {
    final cancelledLog = logsByStatus['cancelled'];
    return [
      _TimelineStep(
        title: _statusLabel('pending'),
        time: _formatOrderDateTime(order.createdAt),
        description: _statusDescription('pending', true),
        done: true,
      ),
      _TimelineStep(
        title: _statusLabel('cancelled'),
        time: _formatOrderDateTime(
          cancelledLog?.createdAt ??
              order.cancelledAt ??
              _bestStatusTime(order),
        ),
        description: _cancelledDescription(order, cancelledLog),
        done: true,
      ),
    ];
  }

  return List.generate(_statusOrder.length, (index) {
    final status = _statusOrder[index];
    final done = statusIndex >= index;
    final log = logsByStatus[status];
    final time = done
        ? _formatOrderDateTime(log?.createdAt ?? _timeForStatus(order, status))
        : 'Chưa cập nhật';
    return _TimelineStep(
      title: _statusLabel(status),
      time: time,
      description: _stepDescription(status, done, log),
      done: done,
    );
  });
}

Map<String, OrderStatusLogModel> _latestLogByStatus(
  List<OrderStatusLogModel> logs,
) {
  final result = <String, OrderStatusLogModel>{};
  for (final log in logs) {
    result[log.status] = log;
  }
  return result;
}

String _stepDescription(String status, bool done, OrderStatusLogModel? log) {
  if (!done) return _statusDescription(status, false);
  final description = log?.description?.trim();
  if (description != null && description.isNotEmpty) return description;
  return _statusDescription(status, true);
}

String _cancelledDescription(OrderModel order, OrderStatusLogModel? log) {
  final note = order.statusNote?.trim();
  if (note != null && note.isNotEmpty) return note;

  final logDescription = log?.description?.trim();
  if (logDescription != null && logDescription.isNotEmpty) {
    return logDescription;
  }

  return _statusDescription('cancelled', true);
}

DateTime _timeForStatus(OrderModel order, String status) {
  return switch (status) {
    'pending' => order.createdAt,
    'picking_up' => order.actualPickedUpAt ?? _bestStatusTime(order),
    'delivered' => order.actualDeliveredAt ?? _bestStatusTime(order),
    _ => _bestStatusTime(order),
  };
}

DateTime _bestStatusTime(OrderModel order) {
  if (order.updatedAt.millisecondsSinceEpoch > 0) return order.updatedAt;
  return order.createdAt;
}

String _formatOrderDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final hour = twoDigits(value.hour);
  final minute = twoDigits(value.minute);
  final day = twoDigits(value.day);
  final month = twoDigits(value.month);
  return '$hour:$minute · $day/$month/${value.year}';
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Đơn hàng đã đặt',
    'confirmed' => 'Đã xác nhận',
    'assigned' => 'Tài xế đã nhận đơn',
    'picking_up' => 'Tài xế đang lấy hàng',
    'delivering' => 'Đang giao đến bạn',
    'delivered' => 'Giao hàng thành công',
    'cancelled' => 'Đã huỷ',
    _ => 'Không rõ',
  };
}

String _statusDescription(String status, bool done) {
  if (!done) {
    return 'Trạng thái này sẽ được cập nhật khi đơn hàng tiếp tục xử lý.';
  }

  return switch (status) {
    'pending' => 'Đơn hàng đã được tạo và đang chờ xử lý.',
    'confirmed' => 'Đơn hàng đã được xác nhận.',
    'assigned' => 'Tài xế đã nhận đơn và đang đến điểm lấy hàng.',
    'picking_up' => 'Tài xế đang lấy hàng từ điểm gửi.',
    'delivering' => 'Tài xế đang mang hàng đến địa chỉ giao.',
    'delivered' => 'Đơn hàng đã được giao thành công.',
    'cancelled' => 'Đơn hàng đã bị huỷ.',
    _ => 'Trạng thái đơn hàng đã được cập nhật.',
  };
}

bool _shouldShowAssignedDriver(String status) {
  return _statusOrder.contains(status) &&
      _statusOrder.indexOf(status) >= _statusOrder.indexOf('assigned');
}

String _serviceTypeLabel(String value) {
  return switch (value) {
    'express' => 'Hoả tốc',
    'fragile' => 'Dễ vỡ',
    'document' => 'Tài liệu',
    _ => 'Tiêu chuẩn',
  };
}

String _paymentMethodLabel(String value) {
  return switch (value) {
    'card' => 'Thẻ',
    'wallet' => 'Ví',
    _ => 'Tiền mặt',
  };
}

String _priceText(OrderModel order) {
  final amount = order.totalPrice ?? order.deliveryFee;
  if (amount <= 0) return 'Chưa tính phí';
  return '${amount.toStringAsFixed(0)}đ';
}

String _joinNonEmpty(List<String?> values) {
  return values
      .map((value) => value?.trim() ?? '')
      .where((value) => value.isNotEmpty)
      .join(' · ');
}

const List<String> _statusOrder = [
  'pending',
  'confirmed',
  'assigned',
  'picking_up',
  'delivering',
  'delivered',
];

bool _shouldShowOrderMap(OrderModel order) {
  if (!_shouldShowAssignedDriver(order.status)) return false;
  if (order.pickupLat == 0 && order.pickupLng == 0) return false;
  if (order.deliveryLat == 0 && order.deliveryLng == 0) return false;
  return true;
}
