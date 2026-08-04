part of 'dashboard_hero.dart';

void _openTracking(BuildContext context, OrderModel order) {
  if (order.trackingCode.trim().isEmpty) {
    context.go('/customer-home?tab=orders');
    return;
  }
  final code = Uri.encodeComponent(order.trackingCode.trim());
  context.go('/customer-home?tab=tracking&code=$code');
}

int _compareActiveOrders(OrderModel a, OrderModel b) {
  final statusCompare = _progressIndex(
    b.status,
  ).compareTo(_progressIndex(a.status));
  if (statusCompare != 0) return statusCompare;
  final aEta = a.estimatedDeliveryAt;
  final bEta = b.estimatedDeliveryAt;
  if (aEta != null && bEta != null) return aEta.compareTo(bEta);
  if (aEta != null) return -1;
  if (bEta != null) return 1;
  return b.updatedAt.compareTo(a.updatedAt);
}

int _progressIndex(String status) => switch (status) {
  'pending' || 'confirmed' => 0,
  'assigned' || 'picking_up' => 1,
  'delivering' => 2,
  'delivered' => 3,
  _ => 0,
};

String _statusLabel(String status) => switch (status) {
  'pending' => 'Chờ xác nhận',
  'confirmed' => 'Đã xác nhận',
  'assigned' => 'Đã có tài xế',
  'picking_up' => 'Đang lấy hàng',
  'delivering' => 'Đang giao',
  _ => 'Đang xử lý',
};

String _statusTitle(String status) => switch (status) {
  'pending' => 'Đang chờ xác nhận',
  'confirmed' => 'Đang tìm tài xế',
  'assigned' => 'Tài xế đang đến lấy hàng',
  'picking_up' => 'Tài xế đang lấy hàng',
  'delivering' => 'Đang giao đến bạn',
  _ => 'Đang cập nhật',
};

String _orderCode(OrderModel order) {
  if (order.trackingCode.trim().isNotEmpty) return order.trackingCode.trim();
  final length = order.id.length >= 8 ? 8 : order.id.length;
  return '#${order.id.substring(0, length).toUpperCase()}';
}

String? _etaText(OrderModel order) {
  final estimated = order.estimatedDeliveryAt;
  if (estimated == null) return null;
  final minutes = estimated.difference(DateTime.now()).inMinutes;
  if (minutes <= 0) return 'Sắp đến';
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '$hours giờ' : '$hours giờ $remainder phút';
}

String? _expectedTime(OrderModel order) {
  final estimated = order.estimatedDeliveryAt;
  if (estimated == null) return null;
  final hour = estimated.hour.toString().padLeft(2, '0');
  final minute = estimated.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
