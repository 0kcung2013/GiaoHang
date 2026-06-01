import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';

class DriverBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const DriverBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: AppSpacing.bottomNavHeight + bottomPadding,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            children: [
              _DriverNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Tong quan',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _DriverNavItem(
                icon: Icons.list_alt_outlined,
                activeIcon: Icons.list_alt_rounded,
                label: 'Don hang',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _DriverNavItem(
                icon: Icons.payments_outlined,
                activeIcon: Icons.payments_rounded,
                label: 'Thu nhap',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _DriverNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Tai khoan',
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

class _DriverNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DriverNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.info : AppColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.info.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: AppSpacing.bottomNavHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: AppDuration.fast,
                curve: AppCurve.decelerate,
                width: active ? 28 : 0,
                height: 3,
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: active ? AppColors.info : Colors.transparent,
                  borderRadius: AppRadius.full,
                ),
              ),
              AnimatedContainer(
                duration: AppDuration.fast,
                curve: AppCurve.decelerate,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.info.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(active ? activeIcon : icon, color: color, size: 22),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
