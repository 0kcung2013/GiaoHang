import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_contact_message.dart';
import '../order_contact_strings.dart';
import '../services/order_message_alert_transport.dart';

class OrderMessageAlertOrder {
  const OrderMessageAlertOrder({
    required this.orderId,
    required this.trackingCode,
    required this.stage,
  });

  final String orderId;
  final String trackingCode;
  final OrderContactStage stage;
}

/// Giữ subscription khi khách đang ở các tab chính và đưa tin tài xế lên một
/// thông báo nổi. Nhấn thông báo sẽ mở đúng chat của đơn tương ứng.
class OrderMessageAlertListener extends StatefulWidget {
  const OrderMessageAlertListener({
    super.key,
    required this.currentUserId,
    required this.activeOrders,
    required this.onOpenChat,
    required this.child,
    this.transport,
  });

  final String currentUserId;
  final List<OrderMessageAlertOrder> activeOrders;
  final ValueChanged<OrderMessageAlertOrder> onOpenChat;
  final Widget child;
  final OrderMessageAlertTransport? transport;

  @override
  State<OrderMessageAlertListener> createState() =>
      _OrderMessageAlertListenerState();
}

class _OrderMessageAlertListenerState extends State<OrderMessageAlertListener> {
  late final OrderMessageAlertTransport _transport;
  final Set<String> _shownMessageIds = <String>{};

  @override
  void initState() {
    super.initState();
    _transport =
        widget.transport ??
        SupabaseOrderMessageAlertTransport(
          client: Supabase.instance.client,
          currentUserId: widget.currentUserId,
        );
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      await _transport.connect(onMessage: _handleMessage);
    } catch (error) {
      debugPrint('[OrderMessageAlert] connect failed: $error');
    }
  }

  void _handleMessage(OrderContactMessage message) {
    if (!mounted ||
        message.senderId == widget.currentUserId ||
        !_shownMessageIds.add(message.id)) {
      return;
    }

    OrderMessageAlertOrder? matchingOrder;
    for (final order in widget.activeOrders) {
      if (order.orderId == message.orderId) {
        matchingOrder = order;
        break;
      }
    }
    if (matchingOrder == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final order = matchingOrder;
    void openChat() {
      messenger.hideCurrentSnackBar();
      widget.onOpenChat(order);
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          padding: EdgeInsets.zero,
          elevation: 10,
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lg,
            side: const BorderSide(color: AppColors.border),
          ),
          content: _IncomingMessageCard(
            message: message.body,
            trackingCode: order.trackingCode,
            onOpen: openChat,
          ),
        ),
      );
  }

  @override
  void dispose() {
    unawaited(_transport.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _IncomingMessageCard extends StatelessWidget {
  const _IncomingMessageCard({
    required this.message,
    required this.trackingCode,
    required this.onOpen,
  });

  final String message;
  final String trackingCode;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: AppRadius.md,
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: AppColors.info,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    OrderContactStrings.incomingDriverMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    OrderContactStrings.orderLabel(trackingCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                minimumSize: const Size(48, 48),
                textStyle: AppTextStyles.labelMedium,
              ),
              child: const Text(OrderContactStrings.viewMessage),
            ),
          ],
        ),
      ),
    );
  }
}
