import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color palette for DATN GiaoHang app
class AppColors {
  // === Brand ===
  static const primary = Color(0xFF0F1B2D); // Deep Navy — trust, authority
  static const accent = Color(0xFFFF6B35); // Vibrant Orange — action, energy
  static const accentLight = Color(0xFFFFEDE6); // Orange tint — backgrounds

  // === Semantic ===
  static const success = Color(0xFF10B981); // Emerald
  static const warning = Color(0xFFF59E0B); // Amber
  static const error = Color(0xFFEF4444); // Rose
  static const info = Color(0xFF3B82F6); // Blue — map, links

  // === Backgrounds ===
  static const bgLight = Color(0xFFF8FAFC); // Screen background (light)
  static const bgCard = Color(0xFFFFFFFF); // Card surface
  static const bgDark = Color(0xFF1E293B); // Dark surface (driver night mode)
  static const bgDarkCard = Color(0xFF243447); // Dark card

  // === Text ===
  static const textPrimary = Color(0xFF0F172A); // Headings, body
  static const textSecondary = Color(0xFF475569); // Subtitles, labels
  static const textMuted = Color(0xFF94A3B8); // Placeholder, hint
  static const textOnDark = Color(0xFFF1F5F9); // Text trên nền tối
  static const textOnAccent = Color(0xFFFFFFFF); // Text trên nút orange

  // === Border ===
  static const border = Color(0xFFE2E8F0); // Divider, input border
  static const borderFocus = Color(0xFF0F1B2D); // Input focused

  // === Map Markers ===
  static const markerPickup = Color(0xFF3B82F6); // Điểm lấy hàng — Blue
  static const markerDrop = Color(0xFFFF6B35); // Điểm giao hàng — Orange
  static const markerDriver = Color(0xFF10B981); // Vị trí tài xế — Green
  static const routeLine = Color(0xFF3B82F6); // Route line trên bản đồ
}

/// Typography styles using Plus Jakarta Sans
class AppTextStyles {
  static final _base = GoogleFonts.plusJakartaSans;

  // Display — màn hình onboarding, hero sections
  static final displayLarge = _base(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2);
  static final displayMedium = _base(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25);

  // Heading — section titles, screen titles
  static final headingLarge = _base(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static final headingMedium = _base(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35);
  static final headingSmall = _base(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);

  // Body — nội dung chính
  static final bodyLarge = _base(fontSize: 15, fontWeight: FontWeight.w400, height: 1.6);
  static final bodyMedium = _base(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);
  static final bodySmall = _base(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);

  // Label — button, badge, chip
  static final labelLarge = _base(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static final labelMedium = _base(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static final labelSmall = _base(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5);

  // Mono — order ID, mã đơn, số liệu
  static final mono = GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w500);
}

/// Spacing constants (base unit: 4px)
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xl2 = 24.0;
  static const xl3 = 32.0;
  static const xl4 = 40.0;
  static const xl5 = 48.0;

  // Screen padding horizontal
  static const screenH = 20.0;

  // Bottom nav safe area
  static const bottomNavHeight = 72.0;
}

/// Border radius constants
class AppRadius {
  static const xs = BorderRadius.all(Radius.circular(6));
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(12));
  static const lg = BorderRadius.all(Radius.circular(16));
  static const xl = BorderRadius.all(Radius.circular(20));
  static const xl2 = BorderRadius.all(Radius.circular(24));
  static const full = BorderRadius.all(Radius.circular(999));
}

/// Shadow constants
class AppShadow {
  static const subtle = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const elevated = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const accentGlow = [
    BoxShadow(color: Color(0x40FF6B35), blurRadius: 20, offset: Offset(0, 6)),
  ];
}

/// Animation durations
class AppDuration {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const page = Duration(milliseconds: 300);
}

/// Animation curves
class AppCurve {
  static const standard = Curves.easeInOut;
  static const decelerate = Curves.easeOut; // Elements vào màn hình
  static const accelerate = Curves.easeIn; // Elements rời màn hình
  static const spring = Curves.elasticOut; // Chỉ dùng cho playful moments
}