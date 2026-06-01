import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/services/auth_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _confirmAndSignOut() async {
    if (_isSigningOut) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AdminLogoutSheet(),
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
          content: Text('Khong the dang xuat. Vui long thu lai.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xl2,
        AppSpacing.screenH,
        AppSpacing.xl2,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cai dat quan tri',
                style: AppTextStyles.headingLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl2),
              _SettingsCard(
                child: Column(
                  children: const [
                    _SettingsRow(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Vai tro quan tri',
                      subtitle: 'Quan ly quyen va cau hinh he thong',
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _SettingsRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Thong bao',
                      subtitle: 'Cau hinh canh bao van hanh',
                    ),
                  ],
                ),
              ),
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
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: ClipRRect(borderRadius: AppRadius.lg, child: child),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
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
    return _SettingsCard(
      child: Material(
        color: AppColors.bgCard,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.error.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.logout_rounded, color: AppColors.error),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Dang xuat',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
                if (isSigningOut)
                  const Icon(
                    Icons.sync_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminLogoutSheet extends StatelessWidget {
  const _AdminLogoutSheet();

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
              'Dang xuat?',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ban co chac muon dang xuat khoi tai khoan admin nay khong?',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl2),
            Row(
              children: [
                Expanded(
                  child: _SheetActionButton(
                    label: 'Huy',
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: AppColors.bgLight,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SheetActionButton(
                    label: 'Dang xuat',
                    foregroundColor: AppColors.textOnAccent,
                    backgroundColor: AppColors.error,
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

class _SheetActionButton extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _SheetActionButton({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: backgroundColor,
        borderRadius: AppRadius.full,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }
}
