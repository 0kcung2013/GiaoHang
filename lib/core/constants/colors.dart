import 'package:flutter/material.dart';

/// Design tokens — GiaoHang App (Warm Accent System)
///
/// Bảng màu riêng cho shell + bottom nav của customer app.
/// Dùng các token này thay vì hardcode hex trong widget.
class NavColors {
  // === Backgrounds ===
  /// Nền ấm chính toàn app (#FAF9F7)
  static const bgWarm = Color(0xFFFAF9F7);

  /// Nền card, nav bar (#FFFFFF)
  static const surface = Color(0xFFFFFFFF);

  // === Brand ===
  /// Màu chủ — cam ấm (#CF7B40)
  static const accent = Color(0xFFCF7B40);

  /// Accent 10% opacity, dùng cho bg tint (#F5E6D8)
  static const accentLight = Color(0xFFF5E6D8);

  /// Accent 8% opacity, dùng cho background tint hình tròn nav
  static const accentTint8 = Color(0x14CF7B40);

  /// Accent 10% opacity, dùng cho InkWell splash
  static const accentSplash = Color(0x1ACF7B40);

  // === Text ===
  /// Text chính (#1C1C1E)
  static const textPrimary = Color(0xFF1C1C1E);

  /// Text phụ, placeholder (#9CA3AF)
  static const textMuted = Color(0xFF9CA3AF);

  /// Text trên accent button (white)
  static const textOnAccent = Color(0xFFFFFFFF);

  // === Border ===
  /// Đường kẻ nhẹ, border card (#F0EDE9)
  static const borderLight = Color(0xFFF0EDE9);

  // === Status badge ===
  /// Đang giao — cam
  static const statusDelivering = Color(0xFFCF7B40);

  /// Hoàn thành — xanh lá
  static const statusDone = Color(0xFF10B981);

  /// Huỷ — đỏ
  static const statusCancelled = Color(0xFFEF4444);

  /// Chờ — xám
  static const statusPending = Color(0xFF9CA3AF);

  // === Destructive ===
  /// Màu đỏ cho nút Đăng xuất (#E24B4A)
  static const danger = Color(0xFFE24B4A);

  // === Shadows ===
  static const List<BoxShadow> navShadow = [
    BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, -2)),
  ];
}