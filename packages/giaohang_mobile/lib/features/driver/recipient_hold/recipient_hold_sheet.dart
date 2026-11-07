import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'recipient_hold_strings.dart';

Future<int?> showRecipientHoldSheet(BuildContext context) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _HoldSheet(),
    );

class _HoldSheet extends StatefulWidget {
  const _HoldSheet();
  @override
  State<_HoldSheet> createState() => _HoldSheetState();
}

class _HoldSheetState extends State<_HoldSheet> {
  int? minutes = 15;
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = minutes ?? int.tryParse(input.text);
    final valid = selected != null && selected >= 1 && selected <= 60;
    final time = DateTime.now().add(Duration(minutes: selected ?? 0));
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              RecipientHoldStrings.choose,
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in [15, 30, 60, null])
                  ChoiceChip(
                    label: Text(
                      value == null
                          ? RecipientHoldStrings.custom
                          : '$value phút',
                    ),
                    selected: minutes == value,
                    selectedColor: AppColors.accentLight,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => setState(() => minutes = value),
                  ),
              ],
            ),
            if (minutes == null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: input,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: RecipientHoldStrings.minutes,
                  helperText: RecipientHoldStrings.invalid,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              valid
                  ? 'Hẹn giao lại lúc ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                  : RecipientHoldStrings.invalid,
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(RecipientHoldStrings.fee, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                textStyle: AppTextStyles.labelLarge,
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(52),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
              ),
              onPressed: valid ? () => Navigator.pop(context, selected) : null,
              child: const Text(RecipientHoldStrings.confirm),
            ),
          ],
        ),
      ),
    );
  }
}
