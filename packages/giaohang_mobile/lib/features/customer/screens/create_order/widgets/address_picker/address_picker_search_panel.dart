import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../address_picker_strings.dart';
import '../../utils/address_search_result.dart';
import 'address_picker_states.dart';

class AddressPickerSearchPanel extends StatelessWidget {
  const AddressPickerSearchPanel({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.results,
    required this.error,
    required this.onChanged,
    required this.onSearch,
    required this.onClear,
    required this.onSelect,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final List<AddressSearchResult> results;
  final String? error;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSearch;
  final VoidCallback onClear;
  final ValueChanged<AddressSearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.subtle,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSearch(),
                  textInputAction: TextInputAction.search,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: AddressPickerStrings.searchHint,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  if (value.text.isEmpty || isSearching) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    tooltip: AddressPickerStrings.clearSearch,
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
              SizedBox(
                width: 46,
                height: 46,
                child: FilledButton(
                  onPressed: isSearching ? null : onSearch,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accentLight,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                  child: isSearching
                      ? const Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.accent,
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textOnAccent,
                        ),
                ),
              ),
            ],
          ),
        ),
        if (results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 224),
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.elevated,
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 54, color: AppColors.border),
              itemBuilder: (_, index) {
                final result = results[index];
                return ListTile(
                  onTap: () => onSelect(result),
                  minLeadingWidth: 34,
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.md,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.accent,
                      size: 19,
                    ),
                  ),
                  title: Text(
                    result.displayAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                );
              },
            ),
          )
        else if (error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.md,
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (isSearching && results.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: AddressInlineLoading(
              label: AddressPickerStrings.searchingAddress,
            ),
          ),
      ],
    );
  }
}
