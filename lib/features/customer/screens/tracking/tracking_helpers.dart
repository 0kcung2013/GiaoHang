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
  final statusIndex = _statusOrder.indexOf(order.status);
  if (order.status == 'cancelled') {
    return [
      _TimelineStep(
        title: 'Đã tạo đơn',
        time: _formatOrderDateTime(order.createdAt),
        description: 'Đơn hàng đã được ghi nhận trong hệ thống.',
        done: true,
      ),
      _TimelineStep(
        title: 'Đã huỷ',
        time: _formatOrderDateTime(_bestStatusTime(order)),
        description: order.statusNote?.trim().isNotEmpty ?? false
            ? order.statusNote!.trim()
            : 'Đơn hàng đã bị huỷ.',
        done: true,
      ),
    ];
  }

  return List.generate(_statusOrder.length, (index) {
    final status = _statusOrder[index];
    final done = statusIndex >= index;
    final time = done
        ? _formatOrderDateTime(_timeForStatus(order, status))
        : 'Chưa cập nhật';
    return _TimelineStep(
      title: _statusLabel(status),
      time: time,
      description: _statusDescription(status, done),
      done: done,
    );
  });
}

_TimelineStep _timelineStepFromLog(OrderStatusLogModel log) {
  return _TimelineStep(
    title: log.title.isEmpty ? _statusLabel(log.status) : log.title,
    time: _formatOrderDateTime(log.createdAt),
    description: log.description?.trim().isNotEmpty ?? false
        ? log.description!.trim()
        : _statusDescription(log.status, true),
    done: true,
  );
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
    'picking_up' => 'Tài xế đang đến lấy hàng',
    'delivering' => 'Đang giao hàng',
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
    'pending' => 'Đơn hàng đã được tạo và đang chờ xác nhận.',
    'confirmed' => 'Đơn hàng đã được xác nhận.',
    'assigned' => 'Tài xế đã nhận đơn và chuẩn bị đến điểm lấy hàng.',
    'picking_up' => 'Tài xế đang đến điểm lấy hàng.',
    'delivering' => 'Đơn hàng đang trên đường giao đến bạn.',
    'delivered' => 'Đơn hàng đã được giao thành công.',
    'cancelled' => 'Đơn hàng đã bị huỷ.',
    _ => 'Trạng thái đơn hàng đã được cập nhật.',
  };
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
