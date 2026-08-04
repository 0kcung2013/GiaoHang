import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../home/widgets/driver_home_layout.dart';
import '../home/widgets/driver_state_widgets.dart';
import 'widgets/driver_orders_body.dart';

class DriverOrdersScreen extends StatelessWidget {
  const DriverOrdersScreen({super.key});

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
                      title: 'Cần đăng nhập',
                      message:
                          'Vui lòng đăng nhập bằng tài khoản tài xế để xem đơn hàng.',
                    )
                  : DriverOrdersBody(userId: currentUser.id),
            ),
          ),
        );
      },
    );
  }
}
