import 'dart:async';
import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../support_orders/data/support_order_repository.dart';
import '../../../support_orders/models/support_order.dart';
import '../../../support_orders/utils/support_order_ui.dart';
import '../../constants/admin_strings.dart';
import '../../data/admin_order_repository.dart';
import '../../dialogs/admin_order_details.dart';
import '../../widgets/admin_order_table.dart';
import '../../widgets/admin_surface.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({
    super.key,
    this.repository,
    this.proofRepository,
    this.initialQuery = '',
  });
  final AdminOrderRepository? repository;
  final SupportOrderRepository? proofRepository;
  final String initialQuery;
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late final _repository =
      widget.repository ??
      SupabaseAdminOrderRepository(Supabase.instance.client);
  late final _search = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  final _scroll = ScrollController();
  List<SupportOrder> _orders = [];
  bool _loading = true, _failed = false, _hasNext = false;
  int _page = 0, _generation = 0;
  String? _status;
  final _opening = <String>{};
  static const statuses = [
    'pending',
    'confirmed',
    'assigned',
    'picking_up',
    'delivering',
    'risk_hold',
    'return_approved',
    'returning',
    'returned',
    'delivered',
    'cancelled',
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _search.text = widget.initialQuery;
      _page = 0;
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await _repository.fetchPage(
        query: _search.text,
        status: _status,
        offset: _page * SupabaseAdminOrderRepository.pageSize,
      );
      if (!mounted || version != _generation) return;
      setState(() {
        _hasNext = rows.length > SupabaseAdminOrderRepository.pageSize;
        _orders = rows.take(SupabaseAdminOrderRepository.pageSize).toList();
      });
    } catch (_) {
      if (mounted && version == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && version == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _open(SupportOrder row) async {
    if (!_opening.add(row.id)) return;
    try {
      await showAdminOrderDetails(
        context,
        row.id,
        _repository,
        proofRepository: widget.proofRepository,
      );
    } finally {
      _opening.remove(row.id);
    }
  }

  void _goPage(int page) {
    _page = page;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      controller: _scroll,
      key: const PageStorageKey('admin-orders-scroll'),
      padding: const EdgeInsets.all(AppSpacing.xl2),
      children: [
        AdminHeading(
          title: AdminStrings.ordersTitle,
          subtitle: AdminStrings.ordersHint,
          action: OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(AdminStrings.refresh),
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SizedBox(
                width: constraints.maxWidth < 540 ? constraints.maxWidth : 340,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: AdminStrings.orderSearch,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: AdminStrings.close,
                            onPressed: () {
                              _search.clear();
                              _page = 0;
                              _load();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), () {
                      _page = 0;
                      _load();
                    });
                  },
                ),
              ),
              SizedBox(
                width: constraints.maxWidth < 540 ? constraints.maxWidth : 240,
                child: DropdownButtonFormField<String>(
                  initialValue: _status ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: AdminStrings.status,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text(AdminStrings.all),
                    ),
                    for (final status in statuses)
                      DropdownMenuItem(
                        value: status,
                        child: Text(SupportOrderUi.statusLabel(status)),
                      ),
                  ],
                  onChanged: (value) {
                    _status = value == '' ? null : value;
                    _page = 0;
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_loading) const LinearProgressIndicator(color: AppColors.accent),
        if (_failed)
          AdminFailure(onRetry: _load)
        else if (!_loading && _orders.isEmpty)
          const AdminSurface(child: Text(AdminStrings.emptyOrders))
        else if (_orders.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          IgnorePointer(
            ignoring: _loading,
            child: AdminOrderTable(orders: _orders, onOpen: _open),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _loading || _page == 0
                  ? null
                  : () {
                      _goPage(_page - 1);
                    },
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text(AdminStrings.previous),
            ),
            Text(AdminStrings.page(_page + 1), style: AppTextStyles.bodySmall),
            OutlinedButton.icon(
              onPressed: _loading || !_hasNext || _failed
                  ? null
                  : () {
                      _goPage(_page + 1);
                    },
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text(AdminStrings.next),
            ),
          ],
        ),
      ],
    ),
  );
}
