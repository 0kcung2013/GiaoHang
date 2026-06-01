import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'drivers/admin_drivers_screen.dart';
import 'orders/admin_orders_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'widgets/admin_bottom_nav.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  static const _tabs = [
    AdminDashboardScreen(),
    AdminOrdersScreen(),
    AdminDriversScreen(),
    AdminSettingsScreen(),
  ];

  static const _titles = [
    'Admin Dashboard',
    'Quan ly don hang',
    'Quan ly tai xe',
    'Cai dat',
  ];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _tabs),
      ),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
