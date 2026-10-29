import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_settings_live.dart';

class BusinessSettingsLifecycle extends StatefulWidget {
  const BusinessSettingsLifecycle({
    super.key,
    required this.client,
    required this.child,
  });
  final SupabaseClient client;
  final Widget child;

  @override
  State<BusinessSettingsLifecycle> createState() =>
      _BusinessSettingsLifecycleState();
}

class _BusinessSettingsLifecycleState extends State<BusinessSettingsLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      BusinessSettingsLive(widget.client).refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
