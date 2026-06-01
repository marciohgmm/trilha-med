import 'package:flutter/material.dart';

import '../../core/commercial/commercial_entitlement.dart';

/// Chip de status para assinatura comercial.
class CommercialStatusChip extends StatelessWidget {
  const CommercialStatusChip({super.key, required this.status});

  final SubscriptionDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colors();
    return Chip(
      label: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      backgroundColor: bg,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  (Color, Color) _colors() {
    switch (status) {
      case SubscriptionDisplayStatus.active:
        return (const Color(0xFF059669), const Color(0xFFD1FAE5));
      case SubscriptionDisplayStatus.lifetime:
        return (const Color(0xFF7C3AED), const Color(0xFFEDE9FE));
      case SubscriptionDisplayStatus.courtesy:
        return (const Color(0xFF0F766E), const Color(0xFFCCFBF1));
      case SubscriptionDisplayStatus.beta:
        return (const Color(0xFF1D4ED8), const Color(0xFFDBEAFE));
      case SubscriptionDisplayStatus.expired:
        return (const Color(0xFFB45309), const Color(0xFFFEF3C7));
      case SubscriptionDisplayStatus.free:
        return (const Color(0xFF4B5563), const Color(0xFFF3F4F6));
    }
  }
}
