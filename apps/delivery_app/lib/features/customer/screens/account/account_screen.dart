import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/services/auth_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const List<_MenuItemData> _menuItems = [
    _MenuItemData(
      icon: Icons.person_outline_rounded,
      label: 'Thông tin cá nhân',
    ),
    _MenuItemData(icon: Icons.location_on_outlined, label: 'Địa chỉ của tôi'),
    _MenuItemData(icon: Icons.history_rounded, label: 'Lịch sử đơn hàng'),
    _MenuItemData(icon: Icons.settings_outlined, label: 'Cài đặt'),
  ];

  bool _isSigningOut = false;

  Future<void> _confirmAndSignOut() async {
    if (_isSigningOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất?'),
          content: const Text(
            'Bạn có chắc muốn đăng xuất khỏi tài khoản này không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      await AuthService().signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể đăng xuất. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _AccountLayout.fromWidth(constraints.maxWidth);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            layout.topPadding,
            layout.horizontalPadding,
            AppSpacing.xl2,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tài khoản',
                    style: AppTextStyles.headingLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: layout.titleGap),
                  const _ProfileHeader(
                    name: 'Nguyễn Minh Tuấn',
                    phone: '0912 345 678',
                  ),
                  SizedBox(height: layout.profileGap),
                  _MenuSection(items: _menuItems),
                  const SizedBox(height: AppSpacing.md),
                  _LogoutRow(
                    isSigningOut: _isSigningOut,
                    onTap: _isSigningOut ? null : _confirmAndSignOut,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const tabletContentMaxWidth = 640.0;
  static const desktopContentMaxWidth = 680.0;

  final double horizontalPadding;
  final double topPadding;
  final double titleGap;
  final double profileGap;
  final double maxContentWidth;

  const _AccountLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.titleGap,
    required this.profileGap,
    required this.maxContentWidth,
  });

  factory _AccountLayout.fromWidth(double width) {
    if (width > desktopBreakpoint) {
      return const _AccountLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        titleGap: AppSpacing.xl3,
        profileGap: AppSpacing.xl3,
        maxContentWidth: desktopContentMaxWidth,
      );
    }

    if (width >= tabletBreakpoint) {
      return const _AccountLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        titleGap: AppSpacing.xl2,
        profileGap: AppSpacing.xl2 + AppSpacing.xs,
        maxContentWidth: tabletContentMaxWidth,
      );
    }

    return const _AccountLayout(
      horizontalPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      titleGap: AppSpacing.xl2,
      profileGap: AppSpacing.xl2 + AppSpacing.xs,
      maxContentWidth: double.infinity,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String phone;

  const _ProfileHeader({required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AvatarInitials(name: name),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs + 1),
                  Text(
                    phone,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  final String name;

  const _AvatarInitials({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: AppTextStyles.headingLarge.copyWith(
            color: AppColors.textOnAccent,
          ),
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName.substring(0, 2).toUpperCase() : 'KH';
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;

  const _MenuItemData({required this.icon, required this.label});
}

class _MenuSection extends StatelessWidget {
  final List<_MenuItemData> items;

  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        children: List.generate(items.length, (index) {
          final isLast = index == items.length - 1;
          return _MenuItem(
            data: items[index],
            showDivider: !isLast,
            onTap: () {},
          );
        }),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(borderRadius: AppRadius.lg, child: child),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final _MenuItemData data;
  final bool showDivider;
  final bool showChevron;
  final Color foregroundColor;
  final Color splashColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.data,
    required this.onTap,
    this.showDivider = true,
    this.showChevron = true,
    this.foregroundColor = AppColors.textPrimary,
    this.splashColor = AppColors.accentLight,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        highlightColor: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg - 1,
              ),
              child: Row(
                children: [
                  Icon(data.icon, color: foregroundColor, size: 22),
                  const SizedBox(width: AppSpacing.md + 2),
                  Expanded(
                    child: Text(
                      data.label,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (showChevron)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                ],
              ),
            ),
            if (showDivider)
              const Divider(height: 1, indent: 52, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  final bool isSigningOut;
  final VoidCallback? onTap;

  const _LogoutRow({required this.isSigningOut, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: _MenuItem(
        data: const _MenuItemData(
          icon: Icons.logout_rounded,
          label: 'Đăng xuất',
        ),
        showDivider: false,
        showChevron: false,
        foregroundColor: AppColors.error,
        splashColor: AppColors.error.withValues(alpha: 0.08),
        trailing: isSigningOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
