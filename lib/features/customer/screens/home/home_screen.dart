import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../account/account_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../order/order_screen.dart';
import '../tracking/tracking_screen.dart';

// ── Customer App Shell — 4-tab Bottom Navigation ────────────────────────────
//
// Điểm đáng chú ý:
//  • Dùng IndexedStack để giữ nguyên trạng thái từng tab khi chuyển qua lại.
//  • Nav bar height = 72px + MediaQuery.padding.bottom để tránh bị che bởi
//    thanh cử chỉ / home indicator trên các thiết bị không nút vật lý.
//  • SafeArea(bottom: false) — safe area phía dưới được xử lý bởi nav bar.
//  • Pill indicator dùng AnimatedContainer width 0→28 khi active.
//  • Background tint (accent 8% opacity, radius 8px) xuất hiện sau icon active.
//  • InkWell splashColor = accent 10% opacity, highlightColor transparent.

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
      backgroundColor: NavColors.bgWarm,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentTab,
          children: pages,
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
      ),
    );
  }
}

// ── Custom Bottom Nav ────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: NavColors.surface,
        border: Border(
          top: BorderSide(color: NavColors.borderLight, width: 1),
        ),
        // Không dùng shadow — chỉ dùng border top theo spec
      ),
      child: SizedBox(
        height: 72 + bottomPadding,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Trang chủ',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Đơn hàng',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.location_on_outlined,
                activeIcon: Icons.location_on_rounded,
                label: 'Theo dõi',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Tài khoản',
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? NavColors.accent : NavColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: NavColors.accentSplash,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ① Animated pill indicator — 0→28px khi active
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: active ? 28 : 0,
                height: 3,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: active ? NavColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              // ② Icon trong vòng tint khi active
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? NavColors.accentTint8
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  active ? activeIcon : icon,
                  color: color,
                  size: 22,
                ),
              ),

              const SizedBox(height: 3),

              // ③ Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                  letterSpacing: active ? 0.1 : 0,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}