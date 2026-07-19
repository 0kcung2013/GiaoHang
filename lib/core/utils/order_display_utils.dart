import '../models/order_model.dart';

/// Mã đơn hiển thị ngắn gọn trong UI / notification.
String formatOrderCode(OrderModel order) {
  final code = order.trackingCode.trim();
  if (code.isNotEmpty) {
    return code.startsWith('GH-') || code.startsWith('#') ? code : 'GH-$code';
  }
  final id = order.id;
  if (id.isEmpty) return 'Đơn hàng';
  final short = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  return 'GH-$short';
}

String shortAddress(String address, {int maxLen = 48}) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return 'điểm lấy hàng';
  if (trimmed.length <= maxLen) return trimmed;
  return '${trimmed.substring(0, maxLen - 1)}…';
}
