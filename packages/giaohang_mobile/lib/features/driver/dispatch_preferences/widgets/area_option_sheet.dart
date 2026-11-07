import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../dispatch_preferences_strings.dart';
import '../utils/area_search.dart';
import 'dispatch_field_decoration.dart';

Future<String?> showAreaOptionSheet(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  String? selected,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.bgCard,
  constraints: const BoxConstraints(maxWidth: 640),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) =>
      _AreaOptionSheet(title: title, options: options, selected: selected),
);

class _AreaOptionSheet extends StatefulWidget {
  const _AreaOptionSheet({
    required this.title,
    required this.options,
    this.selected,
  });
  final String title;
  final Map<String, String> options;
  final String? selected;
  @override
  State<_AreaOptionSheet> createState() => _AreaOptionSheetState();
}

class _AreaOptionSheetState extends State<_AreaOptionSheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final entries = widget.options.entries
        .where(
          (entry) =>
              foldAreaSearch(entry.value).contains(foldAreaSearch(_query)),
        )
        .toList();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height - keyboard) * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.headingMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: DispatchPreferencesStrings.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                style: AppTextStyles.bodyMedium,
                decoration: dispatchFieldDecoration(
                  DispatchPreferencesStrings.filterAreas,
                  suffixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          DispatchPreferencesStrings.noAreasFound,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final selected = widget.selected == entry.key;
                        return Material(
                          color: selected
                              ? AppColors.accentLight
                              : AppColors.bgCard,
                          borderRadius: AppRadius.md,
                          child: ListTile(
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.md,
                            ),
                            selected: selected,
                            selectedColor: AppColors.textPrimary,
                            title: Text(
                              entry.value,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.border,
                            ),
                            onTap: () => Navigator.pop(context, entry.key),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
