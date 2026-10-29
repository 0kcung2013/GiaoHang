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
    this.framed = false,
    super.key,
  });

  final TextEditingController searchController;
  final Key searchKey;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final List<SupportQueueChoice<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;
  final bool framed;

  @override
  Widget build(BuildContext context) => Container(
    padding: framed ? const EdgeInsets.all(AppSpacing.lg) : EdgeInsets.zero,
    decoration: framed
        ? BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
          )
        : null,
    child: Column(
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
            fillColor: framed ? AppColors.bgLight : AppColors.bgCard,
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
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final children = [
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
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      backgroundColor: choice.value == value
                          ? AppColors.bgLight
                          : AppColors.bgCard,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.sm,
                      ),
                      textStyle: AppTextStyles.labelMedium,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: choice.label),
                          TextSpan(
                            text: ' · ${choice.count}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ];
            if (constraints.maxWidth < 600) {
              return _QueueChoiceStrip(children: children);
            }
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: children,
            );
          },
        ),
      ],
    ),
  );
}

/// Các nhóm xử lý cuộn ngang để chừa chỗ cho hồ sơ trên màn hình hẹp.
class _QueueChoiceStrip extends StatefulWidget {
  const _QueueChoiceStrip({required this.children});
  final List<Widget> children;

  @override
  State<_QueueChoiceStrip> createState() => _QueueChoiceStripState();
}

class _QueueChoiceStripState extends State<_QueueChoiceStrip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          for (var i = 0; i < widget.children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            widget.children[i],
          ],
        ],
      ),
    ),
  );
}
