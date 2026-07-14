import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/services/auth_service.dart';

class DriverDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;

  const DriverDrawer({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgCard,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl2),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadius.lg,
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.textOnDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tài xế',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Giao hàng thông minh',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            _DrawerItem(
              icon: Icons.home_rounded,
              label: 'Tổng quan',
              active: currentIndex == 0,
              onTap: () {
                Navigator.of(context).pop();
                onNavigate(0);
              },
            ),
            _DrawerItem(
              icon: Icons.list_alt_rounded,
              label: 'Đơn hàng',
              active: currentIndex == 1,
              onTap: () {
                Navigator.of(context).pop();
                onNavigate(1);
              },
            ),
            _DrawerItem(
              icon: Icons.payments_rounded,
              label: 'Thu nhập',
              active: currentIndex == 2,
              onTap: () {
                Navigator.of(context).pop();
                onNavigate(2);
              },
            ),
            _DrawerItem(
              icon: Icons.person_rounded,
              label: 'Tài khoản',
              active: currentIndex == 3,
              onTap: () {
                Navigator.of(context).pop();
                onNavigate(3);
              },
            ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.border),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Đăng xuất',
              color: AppColors.error,
              onTap: () async {
                Navigator.of(context).pop();
                final confirmed = await showModalBottomSheet<bool>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const _LogoutSheet(),
                );
                if (confirmed == true) {
                  await AuthService().signOut();
                }
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? (active ? AppColors.info : AppColors.textSecondary);
    final bgColor = active ? AppColors.info.withValues(alpha: 0.08) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: bgColor,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: itemColor, size: 22),
                const SizedBox(width: AppSpacing.md),
                Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: itemColor,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đăng xuất?',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Bạn có chắc muốn đăng xuất khỏi tài khoản tài xế này không?',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl2),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    label: 'Huỷ',
                    foreground: AppColors.textPrimary,
                    background: AppColors.bgLight,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SheetButton(
                    label: 'Đăng xuất',
                    foreground: AppColors.textOnAccent,
                    background: AppColors.error,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: background,
        borderRadius: AppRadius.full,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
