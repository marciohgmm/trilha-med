import 'package:flutter/material.dart';

/// Design tokens alinhados ao app (home / admin).
class PracticalPhaseColors {
  PracticalPhaseColors._();

  static const primary = Color(0xFF1E3A8A);
  static const background = Color(0xFFF0F4F8);
  static const card = Colors.white;
  static const accent = Color(0xFFDC2626);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const muted = Color(0xFF6B7280);
}

/// Padding seguro (bordas do dispositivo + margem da seção).
class PracticalPhaseInsets {
  PracticalPhaseInsets._();

  static EdgeInsets page(BuildContext context, {double horizontal = 20}) {
    final safe = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      horizontal + safe.left,
      16,
      horizontal + safe.right,
      24 + safe.bottom,
    );
  }

  static EdgeInsets section(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      20 + safe.left,
      28,
      20 + safe.right,
      0,
    );
  }
}
