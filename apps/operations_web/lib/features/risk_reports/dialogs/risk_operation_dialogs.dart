import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';

Future<bool> showRiskOperationConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.warning_amber_rounded,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _OperationConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon,
    ),
  );
  return confirmed ?? false;
}

Future<String?> showRiskOperationInstructionDialog(
  BuildContext context,
  RiskInterventionState decision,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _InstructionDialog(decision: decision),
  );
}

class _OperationConfirmationDialog extends StatelessWidget {
  const _OperationConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, color: AppColors.accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(title, style: AppTextStyles.headingMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Quay lại'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  key: const Key('confirm-risk-operation'),
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionDialog extends StatefulWidget {
  const _InstructionDialog({required this.decision});

  final RiskInterventionState decision;

  @override
  State<_InstructionDialog> createState() => _InstructionDialogState();
}

class _InstructionDialogState extends State<_InstructionDialog> {
  final _instructionController = TextEditingController();
  final _recipientController = TextEditingController();
  final _destinationController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _instructionController.dispose();
    _recipientController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final returning = widget.decision == RiskInterventionState.returnRequired;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(AppSpacing.xl2),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.xl,
            boxShadow: AppShadow.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                returning ? 'Hướng dẫn hoàn trả' : 'Hướng dẫn bàn giao',
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tài xế sẽ nhìn thấy nguyên văn hướng dẫn này.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('risk-operation-instruction'),
                controller: _instructionController,
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration(
                  label: 'Hướng dẫn bắt buộc',
                  hint: 'Nêu thứ tự thao tác và lưu ý an toàn',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('risk-operation-recipient'),
                controller: _recipientController,
                decoration: _inputDecoration(
                  label: 'Người hoặc đơn vị nhận',
                  hint: 'Ví dụ: Điều phối kho trung tâm',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('risk-operation-destination'),
                controller: _destinationController,
                decoration: _inputDecoration(
                  label: 'Địa điểm / liên hệ',
                  hint: 'Địa chỉ, số điện thoại hoặc điểm hẹn',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Xác nhận'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.bgLight,
      border: const OutlineInputBorder(borderRadius: AppRadius.md),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  void _submit() {
    final instruction = _instructionController.text.trim();
    if (instruction.length < 3) {
      setState(() => _error = 'Vui lòng nhập hướng dẫn.');
      return;
    }
    final recipient = _recipientController.text.trim();
    final destination = _destinationController.text.trim();
    final parts = <String>[instruction];
    if (recipient.isNotEmpty) parts.add('Người nhận: $recipient');
    if (destination.isNotEmpty) parts.add('Địa điểm / liên hệ: $destination');
    Navigator.pop(context, parts.join('\n'));
  }
}
