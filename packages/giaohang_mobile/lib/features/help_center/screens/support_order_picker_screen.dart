import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/mobile_app_role.dart';
import '../../../core/models/order_model.dart';
import '../../order_help/data/customer_support_ticket_repository.dart';
import '../data/help_center_orders.dart';
import '../help_center_strings.dart';
import '../widgets/support_order_conversations.dart';
import '../widgets/support_order_tile.dart';

class SupportOrderPickerScreen extends StatefulWidget {
  const SupportOrderPickerScreen({
    required this.role,
    this.loadOrders,
    this.repository,
    this.requesterId,
    super.key,
  });
  final MobileAppRole role;
  final HelpOrdersLoader? loadOrders;
  final ParticipantSupportTicketRepository? repository;
  final String? requesterId;

  @override
  State<SupportOrderPickerScreen> createState() =>
      _SupportOrderPickerScreenState();
}

class _SupportOrderPickerScreenState extends State<SupportOrderPickerScreen> {
  final _search = TextEditingController();
  late final String? _userId =
      widget.requesterId ?? Supabase.instance.client.auth.currentUser?.id;
  late Future<List<OrderModel>> _orders = _load();
  String _query = '';
  String? _openingId;
  String? _chatError;

  Future<List<OrderModel>> _load() async {
    final userId = _userId;
    if (userId == null) return [];
    final orders =
        await (widget.loadOrders?.call(userId) ??
            loadHelpOrders(widget.role, userId));
    return sortHelpOrders(
      orders.where(
        (order) => widget.role == MobileAppRole.driver
            ? order.driverId == userId
            : order.customerId == userId,
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(OrderModel order) async {
    final userId = _userId;
    if (_openingId != null || userId == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _openingId = order.id;
      _chatError = null;
    });
    try {
      await openHelpOrderChat(
        context,
        order: order,
        requesterId: userId,
        requesterRole: widget.role.name,
        repository:
            widget.repository ?? SupabaseParticipantSupportTicketRepository(),
        onLoaded: () {
          if (mounted) setState(() => _openingId = null);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _chatError = HelpCenterStrings.conversationError);
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(
      title: Text(
        HelpCenterStrings.selectOrder,
        style: AppTextStyles.headingSmall,
      ),
      backgroundColor: AppColors.bgCard,
      surfaceTintColor: AppColors.bgCard,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder<List<OrderModel>>(
            future: _orders,
            builder: (context, snapshot) {
              if (_userId == null) return _message(HelpCenterStrings.signIn);
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }
              if (snapshot.hasError) {
                return _message(HelpCenterStrings.loadError, retry: true);
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return _message(
                  '${HelpCenterStrings.noOrders}\n${HelpCenterStrings.noOrdersHint}',
                );
              }
              final query = _query.trim().toLowerCase();
              final visible = orders
                  .where(
                    (order) =>
                        '${order.trackingCode} ${order.pickupAddress} ${order.deliveryAddress}'
                            .toLowerCase()
                            .contains(query),
                  )
                  .toList();
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                children: [
                  TextField(
                    key: const Key('help-order-search'),
                    controller: _search,
                    style: AppTextStyles.bodyMedium,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      labelText: HelpCenterStrings.searchOrder,
                      labelStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: HelpCenterStrings.clearSearch,
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: AppColors.bgCard,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.md,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_chatError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        _chatError!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  if (visible.isEmpty)
                    Text(
                      HelpCenterStrings.noMatchingOrder,
                      style: AppTextStyles.bodyMedium,
                    ),
                  for (final order in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: SupportOrderTile(
                        order: order,
                        loading: _openingId == order.id,
                        onTap: _openingId == null ? () => _open(order) : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _message(String text, {bool retry = false}) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_rounded, size: 40, color: AppColors.accent),
          const SizedBox(height: AppSpacing.lg),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge,
          ),
          if (retry)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: AppTextStyles.labelMedium,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => setState(() {
                _orders = _load();
              }),
              child: const Text(HelpCenterStrings.retry),
            ),
        ],
      ),
    ),
  );
}
