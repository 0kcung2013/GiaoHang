import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';
import '../models/support_ticket.dart';
import '../utils/support_ticket_ui.dart';

Future<SupportTicketDraft?> showCreateSupportTicketDialog(
  BuildContext context,
) => showDialog<SupportTicketDraft>(
  context: context,
  barrierDismissible: false,
  barrierColor: AppColors.primary.withValues(alpha: 0.46),
  builder: (_) => const CreateSupportTicketDialog(),
);

class CreateSupportTicketDialog extends StatefulWidget {
  const CreateSupportTicketDialog({super.key});

  @override
  State<CreateSupportTicketDialog> createState() =>
      _CreateSupportTicketDialogState();
}

class _CreateSupportTicketDialogState extends State<CreateSupportTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customer = TextEditingController();
  final _order = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  SupportTicketPriority _priority = SupportTicketPriority.normal;

  @override
  void dispose() {
    _customer.dispose();
    _order.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      insetPadding: const EdgeInsets.all(AppSpacing.screenH),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(onClose: () => Navigator.pop(context)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl2,
                  AppSpacing.lg,
                  AppSpacing.xl2,
                  AppSpacing.xl2,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _customer,
                        decoration: _fieldDecoration(
                          label: 'Mã khách hàng *',
                          hint: 'UUID khách hàng',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _order,
                        decoration: _fieldDecoration(
                          label: 'Mã đơn hàng',
                          hint: 'Tùy chọn',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _subject,
                        maxLength: 160,
                        decoration: _fieldDecoration(
                          label: 'Chủ đề *',
                          hint: 'Tóm tắt vấn đề cần hỗ trợ',
                          icon: Icons.subject_rounded,
                        ),
                        validator: (value) => (value ?? '').trim().length < 3
                            ? 'Chủ đề cần ít nhất 3 ký tự.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _message,
                        minLines: 4,
                        maxLines: 6,
                        maxLength: 4000,
                        decoration: _fieldDecoration(
                          label: 'Nội dung *',
                          hint: 'Ghi lại thông tin khách hàng cung cấp',
                          icon: Icons.notes_rounded,
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<SupportTicketPriority>(
                        initialValue: _priority,
                        decoration: _fieldDecoration(
                          label: 'Mức ưu tiên',
                          icon: Icons.flag_outlined,
                        ),
                        items: SupportTicketPriority.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  SupportTicketUi.priorityLabel(item),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _priority = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _DialogActions(onSave: _save),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Thông tin này là bắt buộc.' : null;

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      SupportTicketDraft(
        customerId: _customer.text.trim(),
        orderId: _order.text.trim(),
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        priority: _priority,
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl2,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
    ),
    decoration: const BoxDecoration(
      color: AppColors.bgWarm,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(Icons.add_comment_rounded, color: AppColors.accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            SupportTicketStrings.createTicket,
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: SupportTicketStrings.cancel,
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({required this.onSave});
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            ),
            child: const Text(SupportTicketStrings.cancel),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textOnAccent,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text(SupportTicketStrings.save),
          ),
        ),
      ],
    ),
  );
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  String? hint,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
  prefixIcon: Icon(icon, color: AppColors.textSecondary),
  filled: true,
  fillColor: AppColors.bgLight,
  border: const OutlineInputBorder(
    borderRadius: AppRadius.md,
    borderSide: BorderSide(color: AppColors.border),
  ),
  enabledBorder: const OutlineInputBorder(
    borderRadius: AppRadius.md,
    borderSide: BorderSide(color: AppColors.border),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: AppRadius.md,
    borderSide: BorderSide(color: AppColors.borderFocus, width: 1.5),
  ),
);
