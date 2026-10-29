import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../support/models/support_ticket.dart';
import '../constants/transaction_strings.dart';
import '../models/support_transaction.dart';
import '../utils/transaction_ui.dart';

Future<SupportTicketDraft?> showTransactionRequestDialog(
  BuildContext context,
  SupportTransaction tx,
) => showDialog<SupportTicketDraft>(
  context: context,
  builder: (_) => _RequestDialog(transaction: tx),
);

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.transaction});
  final SupportTransaction transaction;
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  late final TextEditingController _subject;
  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(
      text: TransactionStrings.requestSubject(
        widget.transaction.displayReference,
      ),
    );
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final tx = widget.transaction;
    Navigator.pop(
      context,
      SupportTicketDraft(
        requesterId: tx.userId,
        orderId: tx.orderId,
        subject: _subject.text.trim(),
        priority: SupportTicketPriority.normal,
        message:
            '${tx.requestMarker}\n${TransactionUi.kind(tx)} · ${tx.displayReference}\n'
            'Số tiền: ${TransactionUi.money(tx.amount)}\n\n${_message.text.trim()}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(AppSpacing.lg),
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    TransactionStrings.request,
                    style: AppTextStyles.headingSmall,
                  ),
                ),
                IconButton(
                  tooltip: TransactionStrings.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.transaction.displayUser,
                      style: AppTextStyles.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.transaction.displayReference,
                      style: AppTextStyles.mono,
                    ),
                    if (widget.transaction.trackingCode != null)
                      Text(
                        widget.transaction.trackingCode!,
                        style: AppTextStyles.bodySmall,
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _subject,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: TransactionStrings.subject,
                      ),
                      validator: (v) => (v ?? '').trim().length < 3
                          ? TransactionStrings.enterSubject
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('transaction-request-message'),
                      controller: _message,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 3000,
                      decoration: const InputDecoration(
                        labelText: TransactionStrings.issue,
                      ),
                      validator: (v) => (v ?? '').trim().length < 3
                          ? TransactionStrings.enterIssue
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text(TransactionStrings.saveRequest),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
