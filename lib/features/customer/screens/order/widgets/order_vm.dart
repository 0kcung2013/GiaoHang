import '../../../../../core/models/order_model.dart';

/// View helper that derives display-ready strings from [OrderModel].
/// Keeps the card widget free of formatting logic.
class OrderVm {
  final String orderCode;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final String timeText;
  final String packageType;
  final String priceText;

  const OrderVm({
    required this.orderCode,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.timeText,
    required this.packageType,
    required this.priceText,
  });

  /// Create an [OrderVm] from an [OrderModel].
  factory OrderVm.fromModel(OrderModel o) {
    return OrderVm(
      orderCode: o.trackingCode.isEmpty ? '#${o.id}' : '#${o.trackingCode}',
      status: _statusLabel(o.status),
      pickupAddress: o.pickupAddress,
      deliveryAddress: o.deliveryAddress,
      timeText: _timeText(o),
      packageType: _serviceLabel(o.serviceType),
      priceText: o.totalPrice != null
          ? '${o.totalPrice!.toStringAsFixed(0)}đ'
          : '${o.deliveryFee.toStringAsFixed(0)}đ',
    );
  }

  // ── status → Vietnamese label ──────────────────────────────────
  static String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'assigned':
        return 'Đã phân công';
      case 'picking_up':
        return 'Đang lấy hàng';
      case 'delivering':
        return 'Đang giao';
      case 'delivered':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return s;
    }
  }

  // ── serviceType → Vietnamese label ─────────────────────────────
  static String _serviceLabel(String s) {
    switch (s) {
      case 'express':
        return 'Hỏa tốc';
      case 'bulky':
        return 'Cồng kềnh';
      case 'standard':
      default:
        return 'Tiêu chuẩn';
    }
  }

  // ── relative time text ─────────────────────────────────────────
  static String _timeText(OrderModel o) {
    final dt = o.updatedAt;
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua, ${_hhMm(dt)}';
    return '${dt.day}/${dt.month}, ${_hhMm(dt)}';
  }

  static String _hhMm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}