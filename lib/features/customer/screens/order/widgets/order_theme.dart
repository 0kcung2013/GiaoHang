import 'package:flutter/material.dart';

class OrderColors {
  static const primary = Color(0xFF0F1B2D);
  static const accent = Color(0xFFFF6B35);
  static const accentLight = Color(0xFFFFEDE6);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const bgCard = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
  static const textOnDark = Color(0xFFF1F5F9);
  static const textOnDarkMuted = Color(0xFFCBD5E1);
  static const border = Color(0xFFE2E8F0);
  static const markerPickup = Color(0xFF3B82F6);
  static const markerDrop = Color(0xFFFF6B35);
}

class OrderSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xl3 = 32.0;
  static const screenH = 20.0;
}

class OrderShadow {
  static const subtle = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
}