import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../widgets/admin_placeholder_view.dart';

class AdminDriversScreen extends StatelessWidget {
  const AdminDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPlaceholderView(
      icon: Icons.people_alt_rounded,
      title: 'Tai xe',
      message:
          'Danh sach tai xe, trang thai hoat dong va thong tin phuong tien se duoc bo sung o day.',
      accentColor: AppColors.primary,
    );
  }
}
