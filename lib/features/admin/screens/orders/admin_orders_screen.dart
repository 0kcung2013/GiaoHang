import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../widgets/admin_placeholder_view.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderView(
      icon: Icons.inventory_2_rounded,
      title: 'Don hang',
      message:
          'Danh sach don hang, bo loc trang thai va thao tac phan cong se duoc bo sung o day.',
      accentColor: AppColors.primary,
    );
  }
}
