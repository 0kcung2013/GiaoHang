import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/admin_strings.dart';
import '../../models/admin_section.dart';
import '../../widgets/admin_surface.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key, required this.onNavigate});
  final ValueChanged<AdminSection> onNavigate;
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _busy = false;
  Future<void> _signOut() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AdminStrings.signOutConfirm,
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(AdminStrings.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(AdminStrings.signOut),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AdminStrings.signOutError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.xl2),
    children: [
      const AdminHeading(
        title: AdminStrings.account,
        subtitle: AdminStrings.roleLabelAdmin,
      ),
      const SizedBox(height: AppSpacing.xl2),
      AdminSurface(
        child: Wrap(
          spacing: AppSpacing.xl2,
          runSpacing: AppSpacing.lg,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              color: AppColors.accent,
              size: 32,
            ),
            SelectableText(
              Supabase.instance.client.auth.currentUser?.email ??
                  AdminStrings.missing,
              style: AppTextStyles.labelLarge,
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text(AdminStrings.signOut),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl2),
      const AdminHeading(
        title: AdminStrings.permissions,
        subtitle: AdminStrings.permissionsHint,
      ),
      const SizedBox(height: AppSpacing.lg),
      AdminSurface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final section in [AdminSection.drivers, AdminSection.accounts])
              ListTile(
                leading: Icon(section.icon, color: AppColors.primary),
                title: Text(section.label, style: AppTextStyles.labelMedium),
                subtitle: section == AdminSection.accounts
                    ? const Text(AdminStrings.accountScope)
                    : null,
                trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                onTap: () => widget.onNavigate(section),
              ),
          ],
        ),
      ),
    ],
  );
}
