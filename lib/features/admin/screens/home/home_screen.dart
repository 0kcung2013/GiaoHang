import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../widgets/admin_placeholder_view.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPlaceholderView(
      icon: Icons.dashboard_rounded,
      title: 'Bang dieu khien',
      message:
          'Tong quan don hang, tai xe online va doanh thu se hien thi o day.',
      accentColor: AppColors.primary,
    );
  }
}
