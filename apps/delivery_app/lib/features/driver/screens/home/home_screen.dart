import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'widgets/driver_data_body.dart';
import 'widgets/driver_home_layout.dart';
import 'widgets/driver_state_widgets.dart';

/// Dashboard tab content for the Driver role.
///
/// The parent [DriverShellScreen] owns the Scaffold, AppBar, and bottom nav.
/// This widget keeps the existing Driver Home data/body composition intact.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = DriverHomeLayout.fromWidth(constraints.maxWidth);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            layout.topPadding,
            layout.horizontalPadding,
            AppSpacing.xl2,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
              child: currentUser == null
                  ? const DriverMessageState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Can dang nhap',
                      message:
                          'Vui long dang nhap bang tai khoan tai xe de xem don hang.',
                    )
                  : DriverDashboardBody(userId: currentUser.id, layout: layout),
            ),
          ),
        );
      },
    );
  }
}
