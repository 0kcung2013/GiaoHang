import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/admin_strings.dart';
import '../models/admin_snapshot.dart';
import 'admin_surface.dart';

class AdminAccountList extends StatelessWidget {
  const AdminAccountList({super.key, required this.accounts});
  final List<AdminAccount> accounts;
  @override
  Widget build(BuildContext context) => AdminSurface(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final account in accounts) ...[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.accentLight,
              foregroundColor: AppColors.primary,
              child: Icon(switch (account.role) {
                'driver' => Icons.two_wheeler_rounded,
                'admin' => Icons.admin_panel_settings_rounded,
                'support' => Icons.support_agent_rounded,
                _ => Icons.person_rounded,
              }),
            ),
            title: Text(
              account.name.isEmpty ? AdminStrings.missing : account.name,
              style: AppTextStyles.labelLarge,
            ),
            subtitle: Text(
              [
                AdminStrings.roleLabel(account.role),
                account.email,
                account.phone,
              ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              style: AppTextStyles.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _open(context, account),
          ),
          if (account != accounts.last) const Divider(height: 1),
        ],
      ],
    ),
  );
  Future<void> _open(BuildContext context, AdminAccount account) =>
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AdminStrings.account,
                          style: AppTextStyles.headingMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: AdminStrings.close,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  for (final fact in [
                    (AdminStrings.name, account.name),
                    (AdminStrings.role, AdminStrings.roleLabel(account.role)),
                    (AdminStrings.email, account.email),
                    (AdminStrings.phone, account.phone),
                    (AdminStrings.userId, account.id),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fact.$1,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SelectableText(
                            fact.$2?.isNotEmpty == true
                                ? fact.$2!
                                : AdminStrings.missing,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
