import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../order_contact_strings.dart';

class OrderIncomingMessageButton extends StatefulWidget {
  const OrderIncomingMessageButton({
    super.key,
    required this.buttonKey,
    required this.unreadCount,
    required this.onPressed,
    required this.semanticLabel,
    required this.tooltip,
  });

  final Key buttonKey;
  final int unreadCount;
  final VoidCallback onPressed;
  final String semanticLabel;
  final String tooltip;

  @override
  State<OrderIncomingMessageButton> createState() =>
      _OrderIncomingMessageButtonState();
}

class _OrderIncomingMessageButtonState
    extends State<OrderIncomingMessageButton> {
  OverlayEntry? _dismissTargetOverlay;
  bool _dismissed = false;

  @override
  void didUpdateWidget(covariant OrderIncomingMessageButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dismissed && widget.unreadCount > oldWidget.unreadCount) {
      _dismissed = false;
    }
  }

  void _showDismissTarget() {
    if (_dismissTargetOverlay != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(builder: _buildDismissTargetOverlay);
    _dismissTargetOverlay = entry;
    overlay.insert(entry);
  }

  Widget _buildDismissTargetOverlay(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl3,
            child: Center(
              child: DragTarget<int>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (_) {
                  if (mounted) setState(() => _dismissed = true);
                },
                builder: (context, candidates, _) {
                  final highlighted = candidates.isNotEmpty;
                  return Semantics(
                    label: OrderContactStrings.dismissMessageAlert,
                    child: AnimatedScale(
                      scale: highlighted ? 1.12 : 1,
                      duration: AppDuration.fast,
                      child: Container(
                        key: const Key('order-message-dismiss-target'),
                        width: 104,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(
                            alpha: highlighted ? 0.96 : 0.88,
                          ),
                          borderRadius: AppRadius.xl2,
                          border: Border.all(
                            color: AppColors.textOnDark,
                            width: 2,
                          ),
                          boxShadow: AppShadow.elevated,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.close_rounded,
                              color: AppColors.textOnDark,
                              size: 32,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              OrderContactStrings.dropToDismiss,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textOnDark,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _hideDismissTarget() {
    _dismissTargetOverlay?.remove();
    _dismissTargetOverlay = null;
  }

  @override
  void dispose() {
    _hideDismissTarget();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Draggable<int>(
        data: widget.unreadCount,
        onDragStarted: _showDismissTarget,
        onDragEnd: (_) => _hideDismissTarget(),
        feedback: Material(
          type: MaterialType.transparency,
          child: _MessageBubble(
            unreadCount: widget.unreadCount,
            dragging: true,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.22,
          child: _MessageBubble(
            buttonKey: widget.buttonKey,
            unreadCount: widget.unreadCount,
            onPressed: widget.onPressed,
            tooltip: widget.tooltip,
          ),
        ),
        child: _MessageBubble(
          buttonKey: widget.buttonKey,
          unreadCount: widget.unreadCount,
          onPressed: widget.onPressed,
          tooltip: widget.tooltip,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.unreadCount,
    this.buttonKey,
    this.onPressed,
    this.tooltip,
    this.dragging = false,
  });

  final int unreadCount;
  final Key? buttonKey;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';
    return Semantics(
      excludeSemantics: dragging,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            elevation: 5,
            shadowColor: AppColors.primary.withValues(alpha: 0.28),
            child: InkWell(
              key: buttonKey,
              onTap: dragging ? null : onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: 56,
                child: tooltip == null || dragging
                    ? const Icon(
                        Icons.chat_bubble_rounded,
                        color: AppColors.textOnAccent,
                        size: 27,
                      )
                    : Tooltip(
                        message: tooltip!,
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: AppColors.textOnAccent,
                          size: 27,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: AppRadius.full,
                border: Border.all(color: AppColors.bgCard, width: 2),
              ),
              child: Text(
                badgeLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
