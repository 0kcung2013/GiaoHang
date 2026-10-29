import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/account_strings.dart';
import '../data/account_control_repository.dart';
import '../models/account_command.dart';
import '../models/staff_account.dart';

class AccountDecisionDialog extends StatefulWidget {
  const AccountDecisionDialog({
    super.key,
    required this.account,
    required this.action,
    required this.repository,
    this.riskReportId,
    this.ticketId,
  });
  final StaffAccount account;
  final String action;
  final AccountControlRepository repository;
  final String? riskReportId, ticketId;
  @override
  State<AccountDecisionDialog> createState() => _AccountDecisionDialogState();
}

class _AccountDecisionDialogState extends State<AccountDecisionDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  int? _duration = 30;
  bool _busy = false, _terminal = false;
  String? _error;
  AccountCommand? _command;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _terminal) return;
    if (_command == null) {
      if (!_form.currentState!.validate()) return;
      _command = AccountCommand(
        userId: widget.account.id,
        action: widget.action,
        reason: _reason.text.trim(),
        durationMinutes: widget.action == 'release' ? null : _duration,
        expectedEventId: widget.account.eventId,
        riskReportId: widget.riskReportId,
        ticketId: widget.ticketId,
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.apply(_command!);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      var message = AccountStrings.uncertain;
      if (error is PostgrestException) {
        if (error.code == '40001' || error.code == '23514') {
          message = AccountStrings.changed;
          _terminal = true;
        } else if (error.code == '42501') {
          message = AccountStrings.denied;
          _terminal = true;
        } else if (error.code == '22023' || error.code == 'P0002') {
          message = AccountStrings.invalid;
          _terminal = true;
        }
      }
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Dialog(
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AccountStrings.action(widget.action),
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.account.name.isEmpty
                      ? widget.account.id
                      : widget.account.name,
                  style: AppTextStyles.labelLarge,
                ),
                if (widget.account.email != null)
                  Text(widget.account.email!, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.action == 'release'
                      ? AccountStrings.releaseHint
                      : AccountStrings.confirmation,
                  style: AppTextStyles.bodyMedium,
                ),
                if (widget.account.activeOrders > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AccountStrings.activeOrders(widget.account.activeOrders),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (widget.action != 'release') ...[
                  DropdownButtonFormField<int>(
                    key: const Key('account-duration'),
                    initialValue: _duration ?? 0,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: AccountStrings.duration,
                    ),
                    items: [
                      for (final entry in AccountStrings.durations.entries)
                        DropdownMenuItem(
                          value: entry.key ?? 0,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: _busy || _command != null
                        ? null
                        : (value) => setState(
                            () => _duration = value == 0 ? null : value,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextFormField(
                  controller: _reason,
                  readOnly: _busy || _command != null,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: AccountStrings.reason,
                    helperText: AccountStrings.reasonHint,
                    helperMaxLines: 3,
                  ),
                  validator: (value) {
                    final size = (value ?? '').trim().runes.length;
                    return size < 10 || size > 1000
                        ? AccountStrings.reasonHint
                        : null;
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: LinearProgressIndicator(color: AppColors.accent),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text(AccountStrings.close),
                    ),
                    FilledButton(
                      onPressed: _busy || _terminal ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(48, 48),
                        textStyle: AppTextStyles.labelMedium,
                      ),
                      child: Text(
                        _command != null && _error != null
                            ? AccountStrings.retryCommand
                            : AccountStrings.action(widget.action),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
