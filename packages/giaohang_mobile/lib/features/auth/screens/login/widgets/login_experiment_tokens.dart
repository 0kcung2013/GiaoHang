import 'package:flutter/material.dart';

/// Local tokens for the login design experiment.
///
/// They intentionally stay out of the shared package until the visual
/// direction has been approved for more than one auth screen.
abstract final class LoginExperimentTokens {
  static const heroTop = Color(0xFFFFF0E6);
  static const heroBottom = Color(0xFFFFCFB4);
  static const heroGlow = Color(0xFFFFB47F);
  static const ink = Color(0xFF172238);
  static const muted = Color(0xFF858B98);
  static const field = Color(0xFFF5F6F8);
  static const fieldBorder = Color(0xFFE7E9EE);
  static const accent = Color(0xFFFF5A18);
  static const accentDark = Color(0xFFF24B0B);
  static const surface = Color(0xFFFFFFFF);

  static const mobileSheetRadius = BorderRadius.vertical(
    top: Radius.circular(32),
  );
  static const desktopRadius = BorderRadius.all(Radius.circular(32));
  static const controlRadius = BorderRadius.all(Radius.circular(18));

  static const sheetShadow = [
    BoxShadow(color: Color(0x140F1B2D), blurRadius: 28, offset: Offset(0, -8)),
  ];

  static const ctaShadow = [
    BoxShadow(color: Color(0x38FF5A18), blurRadius: 18, offset: Offset(0, 8)),
  ];
}
