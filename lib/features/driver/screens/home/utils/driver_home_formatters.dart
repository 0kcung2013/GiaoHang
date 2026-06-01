import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';

// ─── Status helpers ────────────────────────────────────────────────────────

String statusLabel(String status) {
  return switch (status) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Chờ tài xế',
    'assigned' => 'Đã phân công',
    'picking_up' => 'Đang lấy',
    'delivering' => 'Đang giao',
    'delivered' => 'Hoàn thành',
    'cancelled' => 'Huỷ',
    _ => 'Không rõ',
  };
}

Color statusColor(String status) {
  return switch (status) {
    'pending' => AppColors.warning,
    'confirmed' => AppColors.info,
    'assigned' => AppColors.info,
    'picking_up' => AppColors.accent,
    'delivering' => AppColors.accent,
    'delivered' => AppColors.success,
    'cancelled' => AppColors.error,
    _ => AppColors.textMuted,
  };
}

IconData statusIcon(String status) {
  return switch (status) {
    'pending' => Icons.access_time_rounded,
    'confirmed' => Icons.inventory_2_rounded,
    'assigned' => Icons.local_shipping_rounded,
    'picking_up' => Icons.storefront_rounded,
    'delivering' => Icons.local_shipping_outlined,
    'delivered' => Icons.check_circle_rounded,
    'cancelled' => Icons.cancel_rounded,
    _ => Icons.help_outline_rounded,
  };
}

// ─── Order helpers ─────────────────────────────────────────────────────────

bool isActiveDriverOrder(OrderModel order) {
  return order.status == 'assigned' ||
      order.status == 'picking_up' ||
      order.status == 'delivering';
}

bool isAvailableOrder(OrderModel order) {
  return (order.driverId == null || order.driverId!.isEmpty) &&
      (order.status == 'pending' || order.status == 'confirmed');
}

String displayOrderCode(OrderModel order) {
  if (order.trackingCode.isNotEmpty) return order.trackingCode;
  final length = order.id.length >= 8 ? 8 : order.id.length;
  return '#${order.id.substring(0, length)}';
}

String priceText(OrderModel order) {
  final amount = order.totalPrice ?? order.deliveryFee;
  if (amount <= 0) return 'Chưa tính phí';
  return '${amount.toStringAsFixed(0)}đ';
}

String serviceTypeLabel(String value) {
  return switch (value) {
    'express' => 'Hỏa tốc',
    'fragile' => 'Dễ vỡ',
    'document' => 'Tài liệu',
    _ => 'Tiêu chuẩn',
  };
}

// ─── String helpers ────────────────────────────────────────────────────────

String joinNonEmpty(List<String?> values) {
  return values
      .map((value) => value?.trim() ?? '')
      .where((value) => value.isNotEmpty)
      .join(' · ');
}
