import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../constants/support_risk_conversion_strings.dart';

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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      SupportRiskConversionDraft(
        category: _category,
        severity: _severity,
        title: _title.text.trim(),
        description: _description.text.trim(),
        component: widget.needsComponent ? _component.text.trim() : null,
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
        helperStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
        helperMaxLines: 2,
        errorMaxLines: 3,
        filled: true,
        fillColor: AppColors.bgLight,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        border: const OutlineInputBorder(borderRadius: AppRadius.md),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.borderFocus, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      );

  Widget _classification() => LayoutBuilder(
    builder: (context, constraints) {
      final category = DropdownButtonFormField<RiskCategory>(
        initialValue: _category,
        isExpanded: true,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: _decoration(SupportRiskConversionStrings.category),
        items: SupportRiskConversionStrings.categories.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (value) =>
            setState(() => _category = value ?? RiskCategory.other),
      );
      final severity = DropdownButtonFormField<RiskSeverity>(
        initialValue: _severity,
        isExpanded: true,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: _decoration(SupportRiskConversionStrings.severity),
        items: SupportRiskConversionStrings.severities.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (value) =>
            setState(() => _severity = value ?? RiskSeverity.medium),
      );
      final stack =
          constraints.maxWidth < 400 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      return stack
          ? Column(
              children: [
                category,
                const SizedBox(height: AppSpacing.lg),
                severity,
              ],
            )
          : Row(
              children: [
                Expanded(child: category),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: severity),
              ],
            );
    },
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.bgCard,
    surfaceTintColor: AppColors.bgCard,
    insetPadding: const EdgeInsets.all(AppSpacing.lg),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              SupportRiskConversionStrings.heading,
              style: AppTextStyles.headingLarge,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xs,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('support-risk-title'),
                      controller: _title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        SupportRiskConversionStrings.title,
                        hint: SupportRiskConversionStrings.titleHint,
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? SupportRiskConversionStrings.titleError
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('support-risk-description'),
                      controller: _description,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      minLines: 3,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      decoration: _decoration(
                        SupportRiskConversionStrings.description,
                        hint: SupportRiskConversionStrings.descriptionHint,
                        helper: SupportRiskConversionStrings.descriptionHelp,
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 10
                          ? SupportRiskConversionStrings.descriptionError
                          : null,
                    ),
                    if (widget.needsComponent) ...[
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        key: const Key('support-risk-component'),
                        controller: _component,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          SupportRiskConversionStrings.component,
                          hint: SupportRiskConversionStrings.componentHint,
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? SupportRiskConversionStrings.componentError
                            : null,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _classification(),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              overflowSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(64, 52),
                    textStyle: AppTextStyles.labelMedium,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(SupportRiskConversionStrings.cancel),
                ),
                FilledButton(
                  key: const Key('confirm-support-risk-conversion'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                    textStyle: AppTextStyles.labelLarge,
                  ),
                  onPressed: _submit,
                  child: const Text(SupportRiskConversionStrings.create),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
