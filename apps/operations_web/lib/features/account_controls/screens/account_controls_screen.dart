import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/widgets/support_workspace_scaffold.dart';
import '../../admin/widgets/admin_surface.dart';
import '../constants/account_strings.dart';
import '../controllers/account_directory_controller.dart';
import '../data/account_control_repository.dart';
import '../dialogs/account_history_dialog.dart';
import '../dialogs/customer_dossier_dialog.dart';
import '../models/staff_account.dart';
import '../widgets/account_list.dart';

class AccountControlsScreen extends StatefulWidget {
  const AccountControlsScreen({
    super.key,
    this.isAdmin = false,
    this.repository,
    this.initialSearch = '',
    this.disabledOnly = false,
    this.riskReportId,
    this.ticketId,
  });
  final bool isAdmin, disabledOnly;
  final String initialSearch;
  final String? riskReportId, ticketId;
  final AccountControlRepository? repository;
  @override
  State<AccountControlsScreen> createState() => _AccountControlsScreenState();
}

class _AccountControlsScreenState extends State<AccountControlsScreen> {
  late final _repository =
      widget.repository ??
      SupabaseAccountControlRepository(Supabase.instance.client);
  late final _controller = AccountDirectoryController(
    _repository,
    search: widget.initialSearch,
    disabledOnly: widget.disabledOnly,
  );
  late final _search = TextEditingController(text: widget.initialSearch);
  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AccountControlsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearch != oldWidget.initialSearch ||
        widget.disabledOnly != oldWidget.disabledOnly) {
      _search.text = widget.initialSearch;
      _controller.filter(
        query: widget.initialSearch,
        disabled: widget.disabledOnly,
      );
    }
  }

  Future<void> _open(StaffAccount account) async {
    final applied = await showDialog<bool>(
      context: context,
      builder: (_) => account.role == 'customer'
          ? CustomerDossierDialog(
              account: account,
              accountRepository: _repository,
              isAdmin: widget.isAdmin,
              riskReportId: widget.riskReportId,
              ticketId: widget.ticketId,
            )
          : AccountHistoryDialog(
              account: account,
              repository: _repository,
              isAdmin: widget.isAdmin,
              riskReportId: widget.riskReportId,
              ticketId: widget.ticketId,
            ),
    );
    if (!mounted) return;
    if (applied == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AccountStrings.completed)));
    }
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          children: [
            AdminHeading(
              title: AccountStrings.title,
              subtitle: widget.isAdmin
                  ? AccountStrings.adminHint
                  : AccountStrings.supportHint,
              action: OutlinedButton.icon(
                onPressed: _controller.loading ? null : _controller.load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(AccountStrings.refresh),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _search,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: AccountStrings.search,
                prefixIcon: Icon(Icons.search_rounded),
                counterText: '',
              ),
              onChanged: (value) => _controller.filter(query: value),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final role in [
                  '',
                  'customer',
                  'driver',
                  if (widget.isAdmin) ...['support', 'admin'],
                ])
                  ChoiceChip(
                    selectedColor: AppColors.accentLight,
                    backgroundColor: AppColors.bgCard,
                    checkmarkColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    label: Text(
                      role.isEmpty
                          ? AccountStrings.all
                          : AccountStrings.role(role),
                    ),
                    selected: (_controller.role ?? '') == role,
                    onSelected: (_) => _controller.filter(roleValue: role),
                  ),
                FilterChip(
                  selectedColor: AppColors.accentLight,
                  backgroundColor: AppColors.bgCard,
                  checkmarkColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  label: const Text(AccountStrings.disabledOnly),
                  avatar: const Icon(Icons.lock_outline_rounded, size: 18),
                  selected: _controller.disabledOnly,
                  onSelected: (value) => _controller.filter(disabled: value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_controller.loading)
              const LinearProgressIndicator(color: AppColors.accent)
            else if (_controller.failed)
              AdminFailure(
                message: AccountStrings.error,
                onRetry: _controller.load,
              )
            else if (_controller.rows.isEmpty)
              const AdminSurface(child: Text(AccountStrings.empty))
            else
              AccountList(accounts: _controller.rows, onOpen: _open),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _controller.loading || _controller.page == 0
                      ? null
                      : () => _controller.move(-1),
                  child: const Text(AccountStrings.previous),
                ),
                Text(
                  AccountStrings.page(_controller.page + 1),
                  style: AppTextStyles.bodySmall,
                ),
                OutlinedButton(
                  onPressed:
                      _controller.loading ||
                          _controller.failed ||
                          !_controller.hasMore
                      ? null
                      : () => _controller.move(1),
                  child: const Text(AccountStrings.next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return widget.isAdmin
        ? content
        : SupportWorkspaceScaffold(
            activeSection: SupportWorkspaceSection.accounts,
            body: content,
          );
  }
}
