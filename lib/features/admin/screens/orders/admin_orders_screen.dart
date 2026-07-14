import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_theme.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  static const _tabs = [
    {'label': 'Tất cả', 'status': null},
    {'label': 'Chờ', 'status': 'pending'},
    {'label': 'Đang giao', 'status': 'delivering'},
    {'label': 'Hoàn thành', 'status': 'delivered'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _fetch();
    });
    _fetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final status = _tabs[_tabController.index]['status'];
      final params = <String, dynamic>{};
      if (status != null) params['p_status'] = status;
      final data = await _supabase.rpc('admin_list_orders', params: params) as List<dynamic>;
      _orders = data.map((o) => Map<String, dynamic>.from(o as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String status) => switch (status) {
    'pending' => AppColors.warning,
    'confirmed' => AppColors.info,
    'assigned' => AppColors.info,
    'picking_up' => AppColors.accent,
    'delivering' => AppColors.accent,
    'delivered' => AppColors.success,
    'cancelled' => AppColors.error,
    _ => AppColors.textMuted,
  };

  String _statusLabel(String status) => switch (status) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Đã xác nhận',
    'assigned' => 'Đã phân công',
    'picking_up' => 'Đang lấy hàng',
    'delivering' => 'Đang giao',
    'delivered' => 'Đã giao',
    'cancelled' => 'Đã hủy',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.bgCard,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTextStyles.labelMedium,
            unselectedLabelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w500),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: _tabs.map((t) => Tab(text: t['label']!)).toList(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
              ? Center(
                  child: Text('Không có đơn hàng nào', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) => _OrderCard(order: _orders[i], statusColor: _statusColor(_orders[i]['status'] ?? ''), statusLabel: _statusLabel(_orders[i]['status'] ?? '')),
                  ),
                ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Color statusColor;
  final String statusLabel;
  const _OrderCard({required this.order, required this.statusColor, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: AppRadius.sm),
                child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order['tracking_code'] ?? '', style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(order['customer_name'] ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: AppRadius.full, border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                child: Text(statusLabel, style: AppTextStyles.labelSmall.copyWith(color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(order['pickup_address'] ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(order['delivery_address'] ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (order['driver_name'] != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('TX: ${order['driver_name']}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],
          if (order['total_price'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${(order['total_price'] as num?)?.toStringAsFixed(0) ?? '0'}đ', style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
