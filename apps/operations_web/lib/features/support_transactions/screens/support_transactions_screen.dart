import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/widgets/support_queue_controls.dart';
import '../../support/widgets/support_workspace_scaffold.dart';
import '../../support_orders/data/support_order_repository.dart';
import '../constants/transaction_strings.dart';
import '../data/transaction_controller.dart';
import '../data/transaction_repository.dart';
import '../dialogs/transaction_detail_dialog.dart';
import '../widgets/transaction_card.dart';
import '../widgets/transaction_filters.dart';

class SupportTransactionsScreen extends StatefulWidget {
  const SupportTransactionsScreen({
    this.repository,
    this.orderRepository,
    super.key,
  });
  final TransactionRepository? repository;
  final SupportOrderRepository? orderRepository;
  @override
  State<SupportTransactionsScreen> createState() =>
      _SupportTransactionsScreenState();
}

class _SupportTransactionsScreenState extends State<SupportTransactionsScreen> {
  late final TransactionController _controller;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _controller = TransactionController(
      widget.repository ??
          SupabaseTransactionRepository(Supabase.instance.client),
    );
    _controller.refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceScaffold(
    activeSection: SupportWorkspaceSection.transactions,
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final controller = _controller;
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.xl2),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SupportQueueHeading(
                            title: TransactionStrings.title,
                            action: OutlinedButton.icon(
                              onPressed: controller.loading
                                  ? null
                                  : controller.refresh,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text(TransactionStrings.refresh),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TransactionFilters(
                            controller: controller,
                            searchController: _search,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (controller.loading)
                            const LinearProgressIndicator(
                              color: AppColors.accent,
                            ),
                          if (controller.error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    controller.error!,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: controller.loading
                                        ? null
                                        : controller.refresh,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text(
                                      TransactionStrings.refresh,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!controller.loading &&
                              controller.rows.isEmpty &&
                              controller.error == null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xl5,
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 40,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    TransactionStrings.empty,
                                    style: AppTextStyles.headingSmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    TransactionStrings.emptyHint,
                                    style: AppTextStyles.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          if (controller.rows.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Text(
                                '${controller.rows.length} ${TransactionStrings.loaded}',
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
                sliver: SliverList.separated(
                  itemCount: controller.rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: TransactionCard(
                        transaction: controller.rows[index],
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => TransactionDetailDialog(
                            transaction: controller.rows[index],
                            repository: controller.repository,
                            serverNow: controller.serverNow,
                            orderRepository: widget.orderRepository,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl2),
                  child: Center(
                    child: controller.loadingMore
                        ? const CircularProgressIndicator(
                            color: AppColors.accent,
                          )
                        : controller.hasMore
                        ? OutlinedButton.icon(
                            onPressed: controller.loading
                                ? null
                                : controller.loadMore,
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text(TransactionStrings.more),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
