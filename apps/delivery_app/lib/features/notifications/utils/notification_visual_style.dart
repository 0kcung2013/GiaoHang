import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../models/notification_inbox_item.dart';

class NotificationVisualStyle {
  const NotificationVisualStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

NotificationVisualStyle notificationVisualStyle(NotificationVisualKind kind) {
  return switch (kind) {
    NotificationVisualKind.orderOffer => const NotificationVisualStyle(
      icon: Icons.local_shipping_rounded,
      color: AppColors.info,
    ),
    NotificationVisualKind.orderProgress => const NotificationVisualStyle(
      icon: Icons.route_rounded,
      color: AppColors.accent,
    ),
    NotificationVisualKind.success => const NotificationVisualStyle(
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
    ),
    NotificationVisualKind.cancellation => const NotificationVisualStyle(
      icon: Icons.cancel_rounded,
      color: AppColors.error,
    ),
    NotificationVisualKind.caseManagement => const NotificationVisualStyle(
      icon: Icons.support_agent_rounded,
      color: AppColors.primary,
    ),
    NotificationVisualKind.system => const NotificationVisualStyle(
      icon: Icons.settings_rounded,
      color: AppColors.textSecondary,
    ),
    NotificationVisualKind.promotion => const NotificationVisualStyle(
      icon: Icons.local_offer_rounded,
      color: AppColors.warning,
    ),
  };
}
