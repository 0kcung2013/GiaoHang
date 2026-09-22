import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/widgets/support_workspace_scaffold.dart';
import '../data/support_order_repository.dart';
import '../dialogs/support_order_detail_dialog.dart';
import '../models/support_order.dart';
import '../widgets/support_order_card.dart';
import '../widgets/support_order_filters.dart';

class SupportOrdersScreen extends StatefulWidget {
  const SupportOrdersScreen({this.repository, super.key});

  final SupportOrderRepository? repository;

  @override
  State<SupportOrdersScreen> createState() => _SupportOrdersScreenState();
}

class _SupportOrdersScreenState extends State<SupportOrdersScreen> {
  final _searchController = TextEditingController();
  late final SupportOrderRepository _repository;
  Timer? _searchDebounce;
  List<SupportOrder> _orders = const [];
  SupportOrderScope _scope = SupportOrderScope.all;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  List<SupportOrder> get _filteredOrders =>
      _orders.where((order) => _scope.includes(order.status)).toList();

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        SupabaseSupportOrderRepository(Supabase.instance.client);
    _loadOrders();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final orders = await _repository.fetchOrders(
        trackingCode: _searchController.text.trim(),
      );
      if (mounted && requestId == _requestId) {
        setState(() {
          _orders = orders;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'Không thể tải danh sách đơn hàng.');
      }
    } finally {
      if (mounted && requestId == _requestId && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  void _search(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadOrders(showLoading: false),
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    _loadOrders(showLoading: false);
  }

  void _openOrder(SupportOrder order) {
    showSupportOrderDetailDialog(
      context,
      order: order,
      repository: _repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceScaffold(
      activeSection: SupportWorkspaceSection.orders,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = math.max(
            AppSpacing.screenH,
            (constraints.maxWidth - 1200) / 2,
          );
          final filtered = _filteredOrders;
          return RefreshIndicator(
            onRefresh: _loadOrders,
            child: CustomScrollView(
              key: const Key('support-orders-scroll-view'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.xl2,
                    horizontalPadding,
                    0,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: _SupportOrdersHeader(),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.xl,
                    horizontalPadding,
                    AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SupportOrderFilters(
                      searchController: _searchController,
                      scope: _scope,
                      resultCount: filtered.length,
                      onSearchChanged: _search,
                      onScopeChanged: (scope) => setState(() => _scope = scope),
                      onClearSearch: _clearSearch,
                    ),
                  ),
                ),
                if (_loading)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      AppSpacing.xl2,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: _SupportOrdersLoading(),
                    ),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _SupportOrdersEmpty(
                      icon: Icons.cloud_off_rounded,
                      title: _error!,
                      subtitle:
                          'Kiểm tra kết nối và quyền truy cập rồi thử lại.',
                      onRetry: _loadOrders,
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _SupportOrdersEmpty(
                      icon: Icons.search_off_rounded,
                      title: _searchController.text.trim().isNotEmpty
                          ? 'Không tìm thấy mã đơn này'
                          : 'Không có đơn hàng phù hợp',
                      subtitle: _searchController.text.trim().isNotEmpty
                          ? 'Kiểm tra lại mã đơn hoặc xóa tìm kiếm.'
                          : 'Thử chọn một nhóm trạng thái khác.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      AppSpacing.xl3,
                    ),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, index) => SupportOrderCard(
                        order: filtered[index],
                        onTap: () => _openOrder(filtered[index]),
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
}

class _SupportOrdersHeader extends StatelessWidget {
  const _SupportOrdersHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl2,
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tra cứu đơn hàng',
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tìm mã đơn, xem hành trình và lịch sử trạng thái.',
                  maxLines: 2,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.textOnDark.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              size: 34,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportOrdersLoading extends StatelessWidget {
  const _SupportOrdersLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 164,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

class _SupportOrdersEmpty extends StatelessWidget {
  const _SupportOrdersEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function({bool showLoading})? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.lg,
              ),
              child: Icon(icon, size: 32, color: AppColors.accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => onRetry!(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
