import 'package:flutter/material.dart';

import '../account/account_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../order/order_screen.dart';
import '../tracking/tracking_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      DashboardScreen(),
      OrderScreen(),
      TrackingScreen(),
      AccountScreen(),
    ];

    return Scaffold(
      backgroundColor: _AppColors.bgLight,
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: pages,
        ),
      ),
      bottomNavigationBar: _CustomerBottomNav(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
      ),
    );
  }
}

class _CustomerBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomerBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: _AppColors.bgCard,
        boxShadow: _AppShadow.subtle,
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Trang chủ',
            active: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.list_alt_rounded,
            label: 'Đơn hàng',
            active: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.map_rounded,
            label: 'Theo dõi',
            active: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Tài khoản',
            active: currentIndex == 3,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _AppColors.primary : _AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppColors {
  static const primary = Color(0xFF0F1B2D);
  static const bgLight = Color(0xFFF8FAFC);
  static const bgCard = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF94A3B8);
}

class _AppShadow {
  static const subtle = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
}