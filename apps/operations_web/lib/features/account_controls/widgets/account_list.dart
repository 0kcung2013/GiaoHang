import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/account_strings.dart';
import '../constants/customer_dossier_strings.dart';
import '../models/staff_account.dart';
import '../utils/account_ui.dart';

class AccountList extends StatelessWidget {
  const AccountList({super.key, required this.accounts, required this.onOpen});
  final List<StaffAccount> accounts;
  final ValueChanged<StaffAccount> onOpen;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < accounts.length; index++) ...[
          if (index > 0) const Divider(height: 1, color: AppColors.border),
          _AccountRow(
            account: accounts[index],
            onTap: () => onOpen(accounts[index]),
          ),
        ],
      ],
    ),
  );
}

class AccountStatus extends StatelessWidget {
  const AccountStatus({super.key, required this.account});
  final StaffAccount account;
  @override
  Widget build(BuildContext context) {
    final color = account.disabled ? AppColors.error : AppColors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              account.disabled
                  ? Icons.lock_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                account.disabled
                    ? AccountStrings.disabledOnly
                    : AccountStrings.enabled,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (account.disabled)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              AccountUi.until(account.disabledUntil),
              style: AppTextStyles.bodySmall,
            ),
          ),
        if (account.disabled && account.reason != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            account.reason!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
          if (account.actorName != null)
            Text(
              account.actorName!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onTap});
  final StaffAccount account;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name.isEmpty ? AccountStrings.missing : account.name,
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AccountStrings.role(account.role),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (account.email?.isNotEmpty == true)
                  Text(account.email!, style: AppTextStyles.bodySmall),
                if (account.phone?.isNotEmpty == true)
                  Text(account.phone!, style: AppTextStyles.bodySmall),
              ],
            );
            final open = TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_outward_rounded, size: 18),
              label: Text(
                account.role == 'customer'
                    ? CustomerDossierStrings.title
                    : AccountStrings.history,
              ),
            );
            if (constraints.maxWidth < 700 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: AppSpacing.md),
                  AccountStatus(account: account),
                  const SizedBox(height: AppSpacing.sm),
                  open,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 4, child: identity),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 3, child: AccountStatus(account: account)),
                const SizedBox(width: AppSpacing.lg),
                open,
              ],
            );
          },
        ),
      ),
    ),
  );
}
