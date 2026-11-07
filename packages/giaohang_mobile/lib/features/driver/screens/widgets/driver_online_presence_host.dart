import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_online_presence_provider.dart';
import '../../../../core/providers/driver_task_priority_provider.dart';

/// Keeps idle GPS alive across tabs without adding dashboard UI.
class DriverOnlinePresenceHost extends ConsumerStatefulWidget {
  const DriverOnlinePresenceHost({
    super.key,
    required this.userId,
    required this.child,
  });
  final String userId;
  final Widget child;

  @override
  ConsumerState<DriverOnlinePresenceHost> createState() =>
      _DriverOnlinePresenceHostState();
}

class _DriverOnlinePresenceHostState
    extends ConsumerState<DriverOnlinePresenceHost>
    with WidgetsBindingObserver {
  String? _profileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retry();
  }

  void _retry() {
    final id = _profileId;
    if (id != null) {
      unawaited(ref.read(driverPresenceSessionProvider(id)).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(driverByUserIdProvider(widget.userId)).valueOrNull;
    final owner = ref.watch(driverLocationOwnerProvider(widget.userId));
    final idle = driver?.isAvailable == true && owner == null;
    _profileId = idle ? driver!.id : null;
    if (idle) {
      // Keep GPS acquisition/recovery alive without inserting status UI.
      ref.watch(driverPresenceSessionProvider(driver!.id));
    }
    return widget.child;
  }
}
