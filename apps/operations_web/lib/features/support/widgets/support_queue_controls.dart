import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/support_ticket_strings.dart';

class SupportQueueHeading extends StatelessWidget {
  const SupportQueueHeading({required this.title, this.action, super.key});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.lg,
    runSpacing: AppSpacing.sm,
    children: [
      Text(title, style: AppTextStyles.headingLarge),
      if (action != null) action!,
    ],
  );
}

class SupportQueueChoice<T> {
  const SupportQueueChoice({
    required this.value,
    required this.label,
    required this.count,
    required this.key,
  });
  final T value;
  final String label;
  final int count;
  final Key key;
}

/// Tìm kiếm và các nhóm xử lý chính của CSKH.
class SupportQueueControls<T> extends StatelessWidget {
  const SupportQueueControls({
    required this.searchController,
    required this.searchKey,
    required this.searchHint,
    required this.onSearchChanged,
    required this.choices,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final TextEditingController searchController;
  final Key searchKey;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final List<SupportQueueChoice<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: searchKey,
        controller: searchController,
        onChanged: onSearchChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          labelText: searchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: SupportTicketStrings.clearSearch,
                  onPressed: () {
                    searchController.clear();
                    onSearchChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: AppColors.bgCard,
          contentPadding: const EdgeInsets.all(AppSpacing.lg),
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
            borderSide: BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final choice in choices)
            Semantics(
              selected: choice.value == value,
              button: true,
              child: TextButton(
                key: choice.key,
                onPressed: () => onChanged(choice.value),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  foregroundColor: choice.value == value
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  backgroundColor: choice.value == value
                      ? AppColors.accentLight
                      : AppColors.bgCard,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                  textStyle: AppTextStyles.labelMedium,
                ),
                child: Text('${choice.label} · ${choice.count}'),
              ),
            ),
        ],
      ),
    ],
  );
}
