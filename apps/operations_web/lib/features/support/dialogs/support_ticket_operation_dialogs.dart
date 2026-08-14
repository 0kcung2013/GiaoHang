import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

class SupportRiskConversionDraft {
  const SupportRiskConversionDraft({
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    this.component,
  });

  final RiskCategory category;
  final RiskSeverity severity;
  final String title;
  final String description;
  final String? component;
}

Future<String?> showSupportResolutionDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Kết luận xử lý'),
      content: TextField(
        key: const Key('support-resolution-field'),
        controller: controller,
        minLines: 3,
        maxLines: 6,
        maxLength: 4000,
        decoration: const InputDecoration(
          hintText: 'Biện pháp đã thực hiện và kết quả cho khách hàng',
          filled: true,
          fillColor: AppColors.bgLight,
          border: OutlineInputBorder(borderRadius: AppRadius.md),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.length >= 3) Navigator.pop(dialogContext, value);
          },
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<SupportRiskConversionDraft?> showSupportRiskConversionDialog(
  BuildContext context, {
  required String initialTitle,
  required String initialDescription,
  required bool needsComponent,
}) {
  return showDialog<SupportRiskConversionDraft>(
    context: context,
    builder: (_) => _SupportRiskConversionDialog(
      initialTitle: initialTitle,
      initialDescription: initialDescription,
      needsComponent: needsComponent,
    ),
  );
}

class _SupportRiskConversionDialog extends StatefulWidget {
  const _SupportRiskConversionDialog({
    required this.initialTitle,
    required this.initialDescription,
    required this.needsComponent,
  });

  final String initialTitle;
  final String initialDescription;
  final bool needsComponent;

  @override
  State<_SupportRiskConversionDialog> createState() =>
      _SupportRiskConversionDialogState();
}

class _SupportRiskConversionDialogState
    extends State<_SupportRiskConversionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  final _component = TextEditingController();
  RiskCategory _category = RiskCategory.other;
  RiskSeverity _severity = RiskSeverity.medium;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _description = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _component.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chuyển thành báo cáo sự cố'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<RiskCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: 'Loại'),
                        items: RiskCategory.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_categoryLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _category = value ?? RiskCategory.other,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<RiskSeverity>(
                        initialValue: _severity,
                        decoration: const InputDecoration(labelText: 'Mức độ'),
                        items: RiskSeverity.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_severityLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _severity = value ?? RiskSeverity.medium,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.needsComponent) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _component,
                    decoration: const InputDecoration(
                      labelText: 'Thành phần hệ thống',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Nhập thành phần bị ảnh hưởng.'
                        : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Tiêu đề quá ngắn.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Dấu hiệu và bằng chứng',
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          key: const Key('confirm-support-risk-conversion'),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              SupportRiskConversionDraft(
                category: _category,
                severity: _severity,
                title: _title.text.trim(),
                description: _description.text.trim(),
                component: widget.needsComponent
                    ? _component.text.trim()
                    : null,
              ),
            );
          },
          icon: const Icon(Icons.shield_outlined),
          label: const Text('Tạo báo cáo'),
        ),
      ],
    );
  }
}

String _severityLabel(RiskSeverity value) => switch (value) {
  RiskSeverity.low => 'Thấp',
  RiskSeverity.medium => 'Trung bình',
  RiskSeverity.high => 'Cao',
  RiskSeverity.critical => 'Nghiêm trọng',
};

String _categoryLabel(RiskCategory value) => switch (value) {
  RiskCategory.deliveryDelay => 'Chậm giao',
  RiskCategory.suspiciousAddress => 'Địa chỉ đáng ngờ',
  RiskCategory.contactIssue => 'Liên lạc',
  RiskCategory.cargoIssue => 'Hàng hóa',
  RiskCategory.repeatedCancellation => 'Hủy lặp lại',
  RiskCategory.payment => 'Thanh toán',
  RiskCategory.safety => 'An toàn',
  RiskCategory.system => 'Hệ thống',
  RiskCategory.other => 'Khác',
};
