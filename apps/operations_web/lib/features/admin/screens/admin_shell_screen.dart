import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../risk_reports/screens/risk_reports_view.dart';
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
    RiskReportsView(isAdmin: true),
    AdminDriversScreen(),
    AdminSettingsScreen(),
  ];

  static const _titles = [
    'Tổng quan',
    'Đơn hàng',
    'Rủi ro',
    'Tài xế',
    'Cài đặt',
  ];
  static const _subtitles = [
    'Theo dõi vận hành hệ thống',
    'Quản lý và lọc đơn giao hàng',
    'Xác minh và xử lý cảnh báo',
    'Duyệt hồ sơ và KYC tài xế',
    'Tài khoản và cấu hình',
  ];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.border,
        titleSpacing: AppSpacing.screenH,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_currentIndex],
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              _subtitles[_currentIndex],
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
