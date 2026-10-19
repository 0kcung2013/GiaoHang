import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';

import 'support_request_alert_strings.dart';
import 'support_request_alerts_host.dart';
import 'support_request_alerts_controller.dart';
import 'support_request_inbox.dart';

class SupportRequestBell extends StatelessWidget {
  const SupportRequestBell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SupportRequestAlertsScope.maybeOf(context);
    final count = controller?.unreadCount ?? 0;
    return IconButton(
      tooltip: SupportRequestAlertStrings.title,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.primary,
      ),
      onPressed: controller == null
          ? null
          : () => _openInbox(context, controller),
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        backgroundColor: AppColors.accent,
        textColor: AppColors.textOnAccent,
        child: Icon(
          controller?.failed == true
              ? Icons.notifications_paused_outlined
              : Icons.notifications_outlined,
        ),
      ),
    );
  }

  Future<void> _openInbox(
    BuildContext context,
    SupportRequestAlertsController controller,
  ) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgCard,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SupportRequestInbox(controller: controller),
    );
    if (id != null && context.mounted) {
      controller.markRead(id);
      context.push('/support-ticket/$id');
    }
  }
}
