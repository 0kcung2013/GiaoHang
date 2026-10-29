import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import '../constants/account_strings.dart';
import '../data/account_control_repository.dart';
import '../models/staff_account.dart';
import '../utils/account_ui.dart';
import '../widgets/account_list.dart';
import 'account_decision_dialog.dart';

class AccountHistoryDialog extends StatefulWidget {
  const AccountHistoryDialog({
    super.key,
    required this.account,
    required this.repository,
    required this.isAdmin,
    this.riskReportId,
    this.ticketId,
  });
  final StaffAccount account;
  final AccountControlRepository repository;
  final bool isAdmin;
  final String? riskReportId, ticketId;
  @override
  State<AccountHistoryDialog> createState() => _AccountHistoryDialogState();
}

class _AccountHistoryDialogState extends State<AccountHistoryDialog> {
  final List<AccountEvent> _events = [];
  bool _loading = true, _failed = false, _hasMore = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.repository.history(
        widget.account.id,
        before: _events.lastOrNull?.sequence,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(result.rows);
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(String action) async {
    final applied = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountDecisionDialog(
        account: widget.account,
        action: action,
        repository: widget.repository,
        riskReportId: widget.riskReportId,
        ticketId: widget.ticketId,
      ),
    );
    // Reload the directory even after an ambiguous result; the underlying state may have changed.
    if (mounted) Navigator.pop(context, applied == true);
  }

  void _openCase(AccountEvent event, bool risk) {
    final id = risk ? event.riskReportId : event.ticketId;
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(
      '${widget.isAdmin ? '/admin' : '/support'}-${risk ? 'case' : 'ticket'}/$id',
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
    insetPadding: const EdgeInsets.all(AppSpacing.lg),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AccountStrings.history,
                    style: AppTextStyles.headingMedium,
                  ),
                ),
                IconButton(
                  tooltip: AccountStrings.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(widget.account.name, style: AppTextStyles.headingSmall),
            SelectableText(
              widget.account.id,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (widget.account.email != null)
              SelectableText(
                widget.account.email!,
                style: AppTextStyles.bodyMedium,
              ),
            if (widget.account.phone != null)
              SelectableText(
                widget.account.phone!,
                style: AppTextStyles.bodyMedium,
              ),
            const SizedBox(height: AppSpacing.lg),
            AccountStatus(account: widget.account),
            if (widget.account.activeOrders > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  AccountStrings.activeOrders(widget.account.activeOrders),
                  style: AppTextStyles.labelMedium,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            if (widget.account.controllable)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (!widget.account.disabled)
                    OutlinedButton.icon(
                      onPressed: () => _decide('disable'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: Text(AccountStrings.action('disable')),
                    ),
                  if (widget.account.disabled && widget.isAdmin) ...[
                    OutlinedButton(
                      onPressed: () => _decide('adjust'),
                      child: Text(AccountStrings.action('adjust')),
                    ),
                    FilledButton(
                      onPressed: () => _decide('release'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: Text(AccountStrings.action('release')),
                    ),
                  ],
                ],
              )
            else
              Text(
                AccountStrings.staffReadOnly,
                style: AppTextStyles.bodySmall,
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Divider(height: 1, color: AppColors.border),
            ),
            for (final event in _events)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AccountStrings.action(event.action),
                      style: AppTextStyles.labelLarge,
                    ),
                    Text(
                      '${AccountUi.date(event.createdAt)} · ${event.actorName ?? ''} · ${AccountStrings.role(event.actorRole)}',
                      style: AppTextStyles.bodySmall,
                    ),
                    if (event.action != 'release')
                      Text(
                        AccountUi.until(event.disabledUntil),
                        style: AppTextStyles.labelMedium,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      event.reason,
                      style: AppTextStyles.bodyMedium,
                    ),
                    if (event.riskReportId != null || event.ticketId != null)
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          if (event.riskReportId != null)
                            TextButton(
                              onPressed: () => _openCase(event, true),
                              child: const Text(AccountStrings.viewIncident),
                            ),
                          if (event.ticketId != null)
                            TextButton(
                              onPressed: () => _openCase(event, false),
                              child: const Text(AccountStrings.viewTicket),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            if (_loading)
              const LinearProgressIndicator(color: AppColors.accent)
            else if (_failed)
              Column(
                children: [
                  Text(AccountStrings.error, style: AppTextStyles.bodyMedium),
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text(AccountStrings.retry),
                  ),
                ],
              )
            else if (_events.isEmpty)
              Text(AccountStrings.historyEmpty, style: AppTextStyles.bodyMedium)
            else if (_hasMore)
              OutlinedButton(
                onPressed: _load,
                child: const Text(AccountStrings.more),
              ),
          ],
        ),
      ),
    ),
  );
}
