import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/support_ticket_strings.dart';
import '../data/support_ticket_repository.dart';
import '../dialogs/create_support_ticket_dialog.dart';
import '../dialogs/support_ticket_detail_dialog.dart';
import '../models/support_ticket.dart';
import '../widgets/support_ticket_card.dart';
import '../widgets/support_ticket_filters.dart';
import '../widgets/support_ticket_header.dart';
import '../widgets/support_ticket_states.dart';
import '../widgets/support_workspace_scaffold.dart';

class SupportHomeScreen extends StatefulWidget {
  const SupportHomeScreen({
    this.repository,
    this.currentUserId,
    this.isAdmin,
    super.key,
  });

  final SupportTicketRepository? repository;
  final String? currentUserId;
  final bool? isAdmin;

  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  final _searchController = TextEditingController();
  late final SupportTicketRepository _repository;
  late final String _currentUserId;
  StreamSubscription<void>? _ticketChangesSubscription;
  List<SupportTicket> _tickets = const [];
  SupportTicketStatus? _status;
  SupportTicketPriority? _priority;
  String _query = '';
  bool _loading = true;
  String? _error;
  bool _isAdmin = false;

  List<SupportTicket> get _filteredTickets {
    final query = _query.trim().toLowerCase();
    final tickets = _tickets.where((ticket) {
      if (_status != null && ticket.status != _status) return false;
      if (_priority != null && ticket.priority != _priority) return false;
      if (query.isEmpty) return true;
      return ticket.subject.toLowerCase().contains(query) ||
          ticket.message.toLowerCase().contains(query) ||
          ticket.customerId.toLowerCase().contains(query) ||
          (ticket.orderId?.toLowerCase().contains(query) ?? false);
    }).toList();
    tickets.sort((left, right) {
      if (left.responseOverdue != right.responseOverdue) {
        return left.responseOverdue ? -1 : 1;
      }
      return right.updatedAt.compareTo(left.updatedAt);
    });
    return tickets;
  }

  @override
  void initState() {
    super.initState();
    if (widget.repository != null && widget.currentUserId != null) {
      _repository = widget.repository!;
      _currentUserId = widget.currentUserId!;
      _isAdmin = widget.isAdmin ?? false;
    } else {
      final client = Supabase.instance.client;
      _repository =
          widget.repository ?? SupabaseSupportTicketRepository(client);
      _currentUserId =
          widget.currentUserId ?? client.auth.currentUser?.id ?? '';
      _isAdmin = widget.isAdmin ?? false;
      if (widget.isAdmin == null) unawaited(_loadRole(client));
    }
    _subscribeToChanges();
    _loadTickets();
  }

  Future<void> _loadRole(SupabaseClient client) async {
    if (_currentUserId.isEmpty) return;
    final row = await client
        .from('users')
        .select('role')
        .eq('id', _currentUserId)
        .maybeSingle();
    if (mounted) setState(() => _isAdmin = row?['role'] == 'admin');
  }

  void _subscribeToChanges() {
    final repository = _repository;
    if (repository is! SupportTicketChangesRepository) return;
    final changes = repository as SupportTicketChangesRepository;
    _ticketChangesSubscription = changes.watchTicketChanges().listen(
      (_) => _loadTickets(showLoading: false),
    );
  }

  @override
  void dispose() {
    unawaited(_ticketChangesSubscription?.cancel());
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tickets = await _repository.fetchTickets();
      if (mounted) setState(() => _tickets = tickets);
    } catch (_) {
      if (mounted) setState(() => _error = SupportTicketStrings.loadingError);
    } finally {
      if (showLoading && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTicket() async {
    final draft = await showCreateSupportTicketDialog(context);
    if (draft == null || !mounted) return;
    try {
      await _repository.createTicket(draft, _currentUserId);
      await _loadTickets();
      if (mounted) _showMessage('Đã ghi nhận yêu cầu hỗ trợ.');
    } catch (_) {
      if (mounted) _showMessage(SupportTicketStrings.createError, error: true);
    }
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => SupportTicketDetailDialog(
        ticket: ticket,
        currentUserId: _currentUserId,
        isAdmin: _isAdmin,
        repository: _repository,
      ),
    );
    if (changed == true) await _loadTickets();
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : AppColors.success,
        ),
      );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _status = null;
      _priority = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceScaffold(
      activeSection: SupportWorkspaceSection.tickets,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = math.max(
            AppSpacing.screenH,
            (constraints.maxWidth - 1200) / 2,
          );
          final filtered = _filteredTickets;
          return RefreshIndicator(
            onRefresh: _loadTickets,
            child: CustomScrollView(
              key: const Key('support-ticket-scroll-view'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.xl2,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SupportTicketHeader(
                      tickets: _tickets,
                      onCreate: _createTicket,
                    ),
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
                    child: SupportTicketFilters(
                      searchController: _searchController,
                      status: _status,
                      priority: _priority,
                      resultCount: filtered.length,
                      totalCount: _tickets.length,
                      onClearFilters: _clearFilters,
                      onSearchChanged: (value) =>
                          setState(() => _query = value),
                      onStatusChanged: (value) =>
                          setState(() => _status = value),
                      onPriorityChanged: (value) =>
                          setState(() => _priority = value),
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
                      child: SupportTicketLoading(),
                    ),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: SupportTicketEmpty(
                      title: _error!,
                      subtitle: SupportTicketStrings.retryHint,
                      onRetry: _loadTickets,
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: SupportTicketEmpty(
                      title: _tickets.isEmpty
                          ? SupportTicketStrings.emptyTitle
                          : SupportTicketStrings.noResults,
                      subtitle: _tickets.isEmpty
                          ? SupportTicketStrings.emptySubtitle
                          : SupportTicketStrings.noResultsHint,
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
                      itemBuilder: (_, index) => SupportTicketCard(
                        ticket: filtered[index],
                        onTap: () => _openTicket(filtered[index]),
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
