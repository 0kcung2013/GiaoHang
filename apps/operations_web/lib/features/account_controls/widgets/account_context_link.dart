import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/admin_workspace_scope.dart';
import '../constants/account_strings.dart';

/// A direct route from an existing case preserves its audit reference.
class AccountContextLink extends StatelessWidget {
  const AccountContextLink({
    super.key,
    required this.userId,
    this.riskReportId,
    this.ticketId,
  });
  final String userId;
  final String? riskReportId, ticketId;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.manage_accounts_outlined, size: 20),
    label: const Text(AccountStrings.manage),
    onPressed: () {
      final admin = AdminWorkspaceScope.contains(context);
      final router = GoRouter.of(context);
      if (ModalRoute.of(context) is PopupRoute) Navigator.pop(context);
      router.push(
        Uri(
          path: admin ? '/admin-home' : '/support-accounts',
          queryParameters: {
            if (admin) 'section': 'accounts',
            'q': userId,
            if (riskReportId != null) 'risk': riskReportId!,
            if (ticketId != null) 'ticket': ticketId!,
          },
        ).toString(),
      );
    },
  );
}
