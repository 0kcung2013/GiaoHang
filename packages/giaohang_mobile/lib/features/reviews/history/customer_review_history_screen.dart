import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';

import '../review_strings.dart';
import 'providers/review_history_provider.dart';
import 'review_history_strings.dart';
import 'widgets/review_history_card.dart';
import 'widgets/review_history_controls.dart';
import 'widgets/review_history_states.dart';

class CustomerReviewHistoryScreen extends ConsumerWidget {
  const CustomerReviewHistoryScreen({super.key});

  void _openOrders(BuildContext context, {String? code}) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(
      code == null
          ? '/customer-home?tab=orders&view=history'
          : '/customer-home?tab=tracking&code=${Uri.encodeComponent(code)}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewHistoryProvider);
    final controller = ref.read(reviewHistoryProvider.notifier);
    final titleStyle = AppTextStyles.headingMedium;
    final scaledTitleSize = MediaQuery.textScalerOf(
      context,
    ).scale(titleStyle.fontSize!);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        toolbarHeight: scaledTitleSize > 24
            ? scaledTitleSize * titleStyle.height! * 2 + AppSpacing.lg
            : kToolbarHeight,
        title: Text(ReviewHistoryStrings.title, style: titleStyle, maxLines: 2),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        foregroundColor: AppColors.primary,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: controller.refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenH),
                itemCount: state.entries.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: ReviewHistoryControls(
                        rating: state.rating,
                        onSelected: controller.selectRating,
                      ),
                    );
                  }
                  if (index <= state.entries.length) {
                    final entry = state.entries[index - 1];
                    final code = entry.trackingCode?.trim();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ReviewHistoryCard(
                        key: ValueKey(entry.review.id),
                        entry: entry,
                        onOpenOrder: code?.isNotEmpty == true
                            ? () => _openOrders(context, code: code)
                            : null,
                      ),
                    );
                  }
                  if (state.loading) return const ReviewHistoryLoading();
                  if (state.failed) {
                    return ReviewHistoryMessage(
                      title: ReviewHistoryStrings.loadError,
                      hint: ReviewHistoryStrings.connectionHint,
                      action: ReviewStrings.retry,
                      onAction: controller.retry,
                      failed: true,
                    );
                  }
                  if (state.entries.isEmpty) {
                    final filtered = state.rating != null;
                    return ReviewHistoryMessage(
                      title: filtered
                          ? ReviewHistoryStrings.filteredEmpty
                          : ReviewHistoryStrings.emptyTitle,
                      hint: filtered
                          ? ReviewHistoryStrings.filteredHint
                          : ReviewHistoryStrings.emptyHint,
                      action: filtered
                          ? ReviewHistoryStrings.clearFilter
                          : ReviewHistoryStrings.orderHistory,
                      onAction: filtered
                          ? () => controller.selectRating(null)
                          : () => _openOrders(context),
                    );
                  }
                  if (state.loadingMore) {
                    return const LinearProgressIndicator(
                      color: AppColors.accent,
                      backgroundColor: AppColors.accentLight,
                      semanticsLabel: ReviewHistoryStrings.loading,
                    );
                  }
                  if (state.hasMore) {
                    return TextButton(
                      onPressed: controller.loadMore,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text(ReviewHistoryStrings.more),
                    );
                  }
                  return const SizedBox(height: AppSpacing.lg);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
