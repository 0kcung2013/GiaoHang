import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import 'account/driver_account_screen.dart';
import 'earnings/driver_earnings_screen.dart';
import 'home/home_screen.dart';
import 'orders/driver_orders_screen.dart';
import 'widgets/driver_bottom_nav.dart';

class DriverShellScreen extends StatefulWidget {
  const DriverShellScreen({super.key});

  @override
  State<DriverShellScreen> createState() => _DriverShellScreenState();
}

class _DriverShellScreenState extends State<DriverShellScreen> {
  static const _tabs = [
    DriverHomeScreen(),
    DriverOrdersScreen(),
    DriverEarningsScreen(),
    DriverAccountScreen(),
  ];

  static const _titles = ['DATN - Tai xe', 'Don hang', 'Thu nhap', 'Tai khoan'];

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
      bottomNavigationBar: DriverBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
