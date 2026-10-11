import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

abstract final class SupportOrderUi {
  static String statusLabel(String status) => switch (status) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Đã xác nhận',
    'assigned' => 'Đã phân công',
    'picking_up' => 'Đang lấy hàng',
    'delivering' => 'Đang giao',
    'delivered' => 'Đã giao',
    'risk_hold' => 'Tạm giữ',
    'return_approved' => 'Đã duyệt hoàn',
    'returning' => 'Đang hoàn hàng',
    'returned' => 'Đã hoàn hàng',
    'cancelled' => 'Đã hủy',
    _ => status,
  };

  static Color statusColor(String status) => switch (status) {
    'pending' => AppColors.warning,
    'confirmed' || 'assigned' => AppColors.info,
    'picking_up' || 'delivering' => AppColors.accent,
    'delivered' || 'returned' => AppColors.success,
    'risk_hold' || 'cancelled' => AppColors.error,
    'return_approved' || 'returning' => AppColors.warning,
    _ => AppColors.textMuted,
  };

  static String formatDateTime(DateTime value) {
    final time = VietnamTime.toWallClock(value);
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)} '
        '${two(time.day)}/${two(time.month)}/${time.year}';
  }

  static String paymentLabel(String? method) => switch (method) {
    'cash' => 'Tiền mặt',
    'vnpay' => 'VNPAY',
    'wallet' => 'Ví',
    'card' => 'Thẻ',
    null || '' => 'Chưa xác định',
    _ => method,
  };

  static String cargoCategoryLabel(String? category) => switch (category) {
    'food' => 'Đồ ăn',
    'document' => 'Tài liệu',
    'parcel' => 'Bưu kiện',
    'fragile' => 'Dễ vỡ',
    'grocery' => 'Tạp hóa',
    'medicine' => 'Thuốc / y tế',
    'electronics' => 'Điện tử',
    'clothes' || 'clothing' => 'Quần áo',
    'gift' => 'Quà tặng',
    'other' => 'Khác',
    null || '' => 'Chưa khai báo',
    _ => category,
  };

  static String feePayerLabel(String? value) => switch (value) {
    'sender' => 'Người gửi',
    'recipient' => 'Người nhận',
    _ => 'Chưa có thông tin',
  };

  static String paymentStatusLabel(String? value) => switch (value) {
    'pending' => 'Chờ thanh toán',
    'paid' => 'Đã thanh toán',
    'not_required' => 'Thu khi giao hàng',
    'failed' => 'Thanh toán thất bại',
    'refunded' => 'Đã hoàn tiền',
    _ => 'Chưa có thông tin',
  };

  static String serviceLabel(String? value) => switch (value) {
    'standard' => 'Giao tiêu chuẩn',
    'express' => 'Giao nhanh',
    'fragile' => 'Hàng dễ vỡ',
    'document' => 'Giao tài liệu',
    _ => value ?? 'Chưa có thông tin',
  };
}
