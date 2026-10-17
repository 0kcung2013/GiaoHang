import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'utils/order_history_filter.dart';
import 'widgets/order_hub_controls.dart';
import 'widgets/order_hub_list.dart';
import 'widgets/order_list_states.dart';

export 'order_helpers.dart'
    show fallbackTimelineSteps, OrderStatusView, formatOrderDateTime;
export 'order_widgets.dart'
    show
        OrderFilterBar,
        OrderCard,
        OrderShimmer,
        OrderEmptyState,
        OrderErrorState,
        OrderLoginRequired;
export 'order_dialogs.dart' show showOrderDetailSheet;

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});
  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  final _searchController = TextEditingController();
  bool _history = false;
  String _query = '';
  OrderHistoryFilter _filter = const OrderHistoryFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              child: OrderHubControls(
                controller: _searchController,
                history: _history,
                onSearch: (value) => setState(() => _query = value.trim()),
                onTab: (value) => setState(() => _history = value),
                onCreate: () => context.push('/customer/create-order'),
              ),
            ),
            Expanded(
              child: user == null
                  ? const OrderLoginRequired()
                  : OrderHubList(
                      customerId: user.id,
                      history: _history,
                      query: _query,
                      filter: _filter,
                      onFilter: (value) {
                        if (mounted) setState(() => _filter = value);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
