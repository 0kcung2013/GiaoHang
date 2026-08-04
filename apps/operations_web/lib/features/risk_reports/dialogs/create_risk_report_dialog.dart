import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';

class CreateRiskReportDialog extends StatefulWidget {
  const CreateRiskReportDialog({super.key});

  @override
  State<CreateRiskReportDialog> createState() => _CreateRiskReportDialogState();
}

class _CreateRiskReportDialogState extends State<CreateRiskReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _trackingCode = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  RiskCategory _category = RiskCategory.deliveryDelay;
  RiskSeverity _severity = RiskSeverity.medium;

  @override
  void dispose() {
    _trackingCode.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      RiskReportDraft(
        trackingCode: _trackingCode.text,
        category: _category,
        severity: _severity,
        title: _title.text,
        description: _description.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: screen.height - AppSpacing.xl3,
        ),
        child: Material(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(onClose: () => Navigator.pop(context)),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl2),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Label(text: 'Mã vận đơn'),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          key: const Key('risk-tracking-code-field'),
                          controller: _trackingCode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _decoration(
                            hint: 'Ví dụ: GH-00001',
                            icon: Icons.inventory_2_outlined,
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Vui lòng nhập mã vận đơn.'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final category = _SelectField<RiskCategory>(
                              label: 'Loại rủi ro',
                              value: _category,
                              items: RiskCategory.values,
                              itemLabel: RiskReportUi.categoryLabel,
                              onChanged: (value) =>
                                  setState(() => _category = value),
                            );
                            final severity = _SelectField<RiskSeverity>(
                              label: 'Mức độ',
                              value: _severity,
                              items: RiskSeverity.values,
                              itemLabel: RiskReportUi.severityLabel,
                              onChanged: (value) =>
                                  setState(() => _severity = value),
                            );
                            if (constraints.maxWidth < 480) {
                              return Column(
                                children: [
                                  category,
                                  const SizedBox(height: AppSpacing.lg),
                                  severity,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: category),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: severity),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _Label(text: 'Tiêu đề'),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          key: const Key('risk-title-field'),
                          controller: _title,
                          maxLength: 160,
                          decoration: _decoration(
                            hint: 'Mô tả ngắn vấn đề cần chú ý',
                            icon: Icons.title_rounded,
                          ),
                          validator: (value) => (value?.trim().length ?? 0) < 3
                              ? 'Tiêu đề cần ít nhất 3 ký tự.'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Label(text: 'Mô tả và bằng chứng'),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          key: const Key('risk-description-field'),
                          controller: _description,
                          maxLength: 4000,
                          minLines: 4,
                          maxLines: 7,
                          decoration: _decoration(
                            hint:
                                'Nêu dấu hiệu, thời điểm và dữ liệu liên quan',
                            icon: Icons.notes_rounded,
                            alignIconTop: true,
                          ),
                          validator: (value) => (value?.trim().length ?? 0) < 10
                              ? 'Mô tả cần ít nhất 10 ký tự.'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.bgLight,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      key: const Key('submit-risk-report-button'),
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textOnAccent,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 19),
                      label: const Text('Gửi báo cáo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    bool alignIconTop = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      prefixIcon: Padding(
        padding: EdgeInsets.only(top: alignIconTop ? AppSpacing.sm : 0),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      filled: true,
      fillColor: AppColors.bgLight,
      border: const OutlineInputBorder(borderRadius: AppRadius.md),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.gpp_maybe_outlined,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Báo cáo rủi ro', style: AppTextStyles.headingMedium),
                Text(
                  'Gắn bằng chứng với một đơn hàng',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SelectField<T> extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(text: label),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            filled: true,
            fillColor: AppColors.bgLight,
            border: OutlineInputBorder(borderRadius: AppRadius.md),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.md,
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
    );
  }
}
