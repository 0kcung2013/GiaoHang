import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

Future<Set<String>?> showRiskMessagePicker(
  BuildContext context,
  List<Map<String, dynamic>> rows,
  Set<String> initial,
) {
  final selected = {...initial};
  return showModalBottomSheet<Set<String>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tin nhắn liên quan',
                      style: AppTextStyles.headingMedium,
                    ),
                  ),
                  Semantics(
                    button: true,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, selected),
                      borderRadius: AppRadius.full,
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            'Xong',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có tin nhắn',
                        style: AppTextStyles.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.border),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final id = row['id'].toString();
                        final checked = selected.contains(id);
                        return CheckboxListTile(
                          value: checked,
                          activeColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            row['body']?.toString() ??
                                '[Tin nhắn đa phương tiện]',
                            style: AppTextStyles.bodyMedium,
                          ),
                          onChanged: (_) => setModalState(() {
                            checked ? selected.remove(id) : selected.add(id);
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
