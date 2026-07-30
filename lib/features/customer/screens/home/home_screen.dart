import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../account/account_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../order/order_screen.dart';
import '../tracking/tracking_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    this.initialTab = 0,
    this.initialTrackingCode,
  });

  final int initialTab;
  final String? initialTrackingCode;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late int _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab.clamp(0, 3);
  }

  @override
  void didUpdateWidget(covariant CustomerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _currentTab = widget.initialTab.clamp(0, 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardScreen(),
      const OrderScreen(),
      TrackingScreen(initialTrackingCode: widget.initialTrackingCode),
      const AccountScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentTab, children: pages),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
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

class _NavItem extends StatefulWidget {
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
    required this.active,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.accent : AppColors.textSecondary;

    return Expanded(
      child: Semantics(
        selected: widget.active,
        button: true,
        label: widget.label,
        child: InkWell(
          onTap: widget.onTap,
          splashColor: AppColors.accent.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppDuration.fast,
                  curve: AppCurve.decelerate,
                  width: 48,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.active
                        ? AppColors.accentLight
                        : Colors.transparent,
                    borderRadius: AppRadius.full,
                  ),
                  child: Icon(
                    widget.active ? widget.activeIcon : widget.icon,
                    color: widget.active ? AppColors.accent : color,
                    size: 23,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: widget.active
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
