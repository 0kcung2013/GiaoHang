import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/services/auth_service.dart';

class DriverDrawer extends StatelessWidget {
  const DriverDrawer({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
  });

  final int currentIndex;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl2),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, Color(0xFFFF945F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppRadius.lg,
                      boxShadow: AppShadow.accentGlow,
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.textOnAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Không gian tài xế',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
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
            const Divider(height: 1, color: AppColors.accentLight),
            const SizedBox(height: AppSpacing.md),
            _DrawerItem(
              icon: Icons.home_rounded,
              label: 'Tổng quan',
              active: currentIndex == 0,
              onTap: () => _navigate(context, 0),
            ),
            _DrawerItem(
              icon: Icons.list_alt_rounded,
              label: 'Đơn hàng',
              active: currentIndex == 1,
              onTap: () => _navigate(context, 1),
            ),
            _DrawerItem(
              icon: Icons.payments_rounded,
              label: 'Thu nhập',
              active: currentIndex == 2,
              onTap: () => _navigate(context, 2),
            ),
            _DrawerItem(
              icon: Icons.person_rounded,
              label: 'Tài khoản',
              active: currentIndex == 3,
              onTap: () => _navigate(context, 3),
            ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.border),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Đăng xuất',
              color: AppColors.error,
              onTap: () => _confirmSignOut(context),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, int index) {
    Navigator.of(context).pop();
    onNavigate(index);
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    Navigator.of(context).pop();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogoutSheet(),
    );
    if (confirmed == true) await AuthService().signOut();
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemColor =
        color ?? (active ? AppColors.accent : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: active ? AppColors.accentLight : Colors.transparent,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: itemColor, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: itemColor,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
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
          borderRadius: AppRadius.xl2,
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
                fontWeight: FontWeight.w800,
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
                    background: AppColors.accent,
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
  const _SheetButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

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
