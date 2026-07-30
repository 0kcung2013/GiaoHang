part of 'map_picker_sheet.dart';

class _AddressSearchPanel extends StatelessWidget {
  const _AddressSearchPanel({
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
            color: AppColors.bgCard.withValues(alpha: 0.97),
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.card,
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
                  textInputAction: TextInputAction.search,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSearch(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nhập địa chỉ cần tìm',
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
                    tooltip: 'Xóa tìm kiếm',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  );
                },
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: FilledButton(
                  onPressed: isSearching ? null : () => onSearch(),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accentLight,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                  child: isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textOnAccent,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ),
        if (results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 244),
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
                  const Divider(height: 1, indent: 52, color: AppColors.border),
              itemBuilder: (context, index) {
                final result = results[index];
                return _AddressSearchResultTile(
                  result: result,
                  onTap: () => onSelect(result),
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
                color: AppColors.warning.withValues(alpha: 0.45),
              ),
              boxShadow: AppShadow.subtle,
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
      ],
    );
  }
}

class _AddressSearchResultTile extends StatelessWidget {
  const _AddressSearchResultTile({required this.result, required this.onTap});

  final AddressSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rawAddress = result.rawDisplayName.trim();
    final showRawAddress =
        rawAddress.isNotEmpty && rawAddress != result.displayAddress;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.md,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.accent,
                size: 19,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.displayAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (showRawAddress) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      rawAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
