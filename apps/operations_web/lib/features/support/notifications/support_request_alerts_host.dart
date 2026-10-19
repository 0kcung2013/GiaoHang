import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_request_alerts_controller.dart';
import 'support_request_alerts_repository.dart';
import 'support_request_toast.dart';

class SupportRequestAlertsScope
    extends InheritedNotifier<SupportRequestAlertsController> {
  const SupportRequestAlertsScope({
    required SupportRequestAlertsController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static SupportRequestAlertsController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SupportRequestAlertsScope>()
          ?.notifier;
}

/// One subscription survives navigation between all CSKH workspaces.
class SupportRequestAlertsHost extends StatefulWidget {
  const SupportRequestAlertsHost({
    required this.child,
    this.repository,
    super.key,
  });
  final Widget child;
  final SupportRequestAlertsRepository? repository;

  @override
  State<SupportRequestAlertsHost> createState() =>
      _SupportRequestAlertsHostState();
}

class _SupportRequestAlertsHostState extends State<SupportRequestAlertsHost> {
  late final _controller = SupportRequestAlertsController(
    widget.repository ??
        SupabaseSupportRequestAlertsRepository(Supabase.instance.client),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SupportRequestAlertsScope(
    controller: _controller,
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final latest = _controller.latest;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (latest != null)
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SupportRequestToast(
                          ticket: latest,
                          onDismiss: _controller.dismissToast,
                          onOpen: () {
                            _controller.markRead(latest.id);
                            context.push('/support-ticket/${latest.id}');
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
