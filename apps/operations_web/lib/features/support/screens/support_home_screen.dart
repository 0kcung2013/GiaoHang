import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/support_ticket_strings.dart';
import '../constants/support_monitoring_strings.dart';
import '../data/support_ticket_repository.dart';
import '../dialogs/create_support_ticket_dialog.dart';
import '../dialogs/support_ticket_detail_dialog.dart';
import '../models/support_ticket.dart';
import '../models/support_queue_scope.dart';
import '../models/support_chat_category.dart';
import '../widgets/support_chat_categories.dart';
import '../widgets/support_ticket_card.dart';
import '../widgets/support_ticket_columns.dart';
import '../widgets/support_queue_controls.dart';
import '../widgets/support_ticket_header.dart';
import '../widgets/support_ticket_states.dart';
import '../widgets/support_workspace_scaffold.dart';

class SupportHomeScreen extends StatefulWidget {
  const SupportHomeScreen({
    this.repository,
    this.currentUserId,
    this.isAdmin,
    this.monitoring = false,
    this.waitingAdminOnly = false,
    this.onClearWaitingAdminFilter,
    super.key,
  });

  final SupportTicketRepository? repository;
  final String? currentUserId;
  final bool? isAdmin;
  final bool monitoring;
  final bool waitingAdminOnly;
  final VoidCallback? onClearWaitingAdminFilter;

  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  final _searchController = TextEditingController();
  late final SupportTicketRepository _repository;
  late final String _currentUserId;
  StreamSubscription<void>? _ticketChangesSubscription;
  List<SupportTicket> _tickets = const [];
  String _query = '';
  SupportQueueScope _scope = SupportQueueScope.active;
  SupportChatCategory _category = SupportChatCategory.general;
  bool _loading = true;
  bool _refreshing = false;
  bool _hasLoaded = false;
  int _loadVersion = 0;
  String? _error;
  bool _isAdmin = false;

  Iterable<SupportTicket> get _sectionTickets => _tickets.where(
    (ticket) => widget.waitingAdminOnly
        ? ticket.status == SupportTicketStatus.waitingAdmin
        : widget.monitoring
        ? ticket.isMonitoring
        : _category.includes(ticket),
  );

  List<SupportTicket> get _filteredTickets {
    final query = _query.trim().toLowerCase();
    final tickets = _sectionTickets.where((ticket) {
      if (!_scope.includes(ticket, _currentUserId)) return false;
      if (query.isEmpty) return true;
      return ticket.subject.toLowerCase().contains(query) ||
          (ticket.trackingCode?.toLowerCase().contains(query) ?? false) ||
          ticket.message.toLowerCase().contains(query) ||
          ticket.requesterId.toLowerCase().contains(query) ||
          (ticket.requesterName?.toLowerCase().contains(query) ?? false) ||
          (ticket.orderId?.toLowerCase().contains(query) ?? false);
    }).toList();
    tickets.sort((left, right) {
      if (_scope == SupportQueueScope.finished ||
          _scope == SupportQueueScope.automatic) {
        return right.updatedAt.compareTo(left.updatedAt);
      }
      final priority = right.priority.index.compareTo(left.priority.index);
      if (priority != 0) return priority;
      return left.updatedAt.compareTo(right.updatedAt);
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

  @override
  void didUpdateWidget(covariant SupportHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waitingAdminOnly != widget.waitingAdminOnly) {
      _scope = SupportQueueScope.active;
      _query = '';
      _searchController.clear();
    }
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
      (_) => _loadTickets(),
    );
  }

  @override
  void dispose() {
    unawaited(_ticketChangesSubscription?.cancel());
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final version = ++_loadVersion;
    setState(() {
      _loading = !_hasLoaded;
      _refreshing = _hasLoaded;
      _error = null;
    });
    try {
      final tickets = await _repository.fetchTickets();
      if (mounted && version == _loadVersion) {
        setState(() {
          _tickets = tickets;
          _hasLoaded = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = SupportTicketStrings.loadingError);
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _createTicket() async {
    final draft = await showCreateSupportTicketDialog(context);
    if (draft == null || !mounted) return;
    try {
      await _repository.createTicket(draft, _currentUserId);
      if (mounted && !widget.monitoring) {
        setState(() {
          _category = draft.orderId?.trim().isNotEmpty == true
              ? SupportChatCategory.order
              : SupportChatCategory.general;
          _scope = SupportQueueScope.active;
          _query = '';
          _searchController.clear();
        });
      }
      await _loadTickets();
      if (mounted) _showMessage('Đã ghi nhận yêu cầu hỗ trợ.');
    } catch (_) {
      if (mounted) _showMessage(SupportTicketStrings.createError, error: true);
    }
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    if (widget.repository == null) {
      await context.push('/support-ticket/${ticket.id}');
      if (mounted) await _loadTickets();
      return;
    }
    await showDialog<bool>(
      context: context,
      builder: (_) => SupportTicketDetailDialog(
        ticket: ticket,
        currentUserId: _currentUserId,
        isAdmin: _isAdmin,
        repository: _repository,
      ),
    );
    if (mounted) await _loadTickets();
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

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceScaffold(
      activeSection: widget.monitoring
          ? SupportWorkspaceSection.monitoring
          : SupportWorkspaceSection.tickets,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = math.max(
            AppSpacing.screenH,
            (constraints.maxWidth - 1280) / 2,
          );
          final filtered = _filteredTickets;
          return RefreshIndicator(
            onRefresh: _loadTickets,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SupportTicketHeader(
                          title: widget.waitingAdminOnly
                              ? SupportTicketStrings.waitingAdminTitle
                              : widget.monitoring
                              ? SupportMonitoringStrings.casesTitle
                              : SupportTicketStrings.ticketsTitle,
                          onCreate: widget.monitoring || widget.waitingAdminOnly
                              ? null
                              : _createTicket,
                          onRefresh: _loadTickets,
                          refreshing: _loading || _refreshing,
                        ),
                        if (widget.waitingAdminOnly &&
                            widget.onClearWaitingAdminFilter != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: widget.onClearWaitingAdminFilter,
                              icon: const Icon(Icons.filter_alt_off_rounded),
                              label: const Text(
                                SupportTicketStrings.allSupportRequests,
                              ),
                            ),
                          ),
                        if (!widget.monitoring && !widget.waitingAdminOnly) ...[
                          const SizedBox(height: AppSpacing.xl),
                          SupportChatCategories(
                            value: _category,
                            onChanged: (value) =>
                                setState(() => _category = value),
                          ),
                        ],
                        if (widget.monitoring) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _scope == SupportQueueScope.automatic
                                ? SupportMonitoringStrings.logHint
                                : SupportMonitoringStrings.queueHint,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
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
                    child: SupportQueueControls<SupportQueueScope>(
                      framed: constraints.maxWidth >= 600,
                      searchController: _searchController,
                      searchKey: const Key('support-ticket-search'),
                      searchHint: SupportTicketStrings.searchHint,
                      onSearchChanged: (value) =>
                          setState(() => _query = value),
                      value: _scope,
                      onChanged: (value) => setState(() => _scope = value),
                      choices: [
                        for (final scope in [
                          SupportQueueScope.active,
                          SupportQueueScope.mine,
                          if (!widget.monitoring) SupportQueueScope.unassigned,
                          if (!widget.monitoring) SupportQueueScope.needsReply,
                          if (!widget.waitingAdminOnly)
                            SupportQueueScope.finished,
                          if (widget.monitoring) SupportQueueScope.automatic,
                        ])
                          SupportQueueChoice(
                            value: scope,
                            label:
                                widget.monitoring &&
                                    scope == SupportQueueScope.active
                                ? SupportMonitoringStrings.intervention
                                : scope == SupportQueueScope.finished
                                ? SupportTicketStrings.finished
                                : scope.label,
                            count: _sectionTickets
                                .where(
                                  (ticket) =>
                                      scope.includes(ticket, _currentUserId),
                                )
                                .length,
                            key: ValueKey('support-queue-${scope.name}'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_hasLoaded)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      AppSpacing.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_refreshing)
                            const LinearProgressIndicator(
                              color: AppColors.accent,
                              semanticsLabel:
                                  SupportTicketStrings.refreshingQueue,
                            ),
                          if (_error != null)
                            Wrap(
                              spacing: AppSpacing.sm,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  SupportTicketStrings.staleQueue,
                                  style: AppTextStyles.bodyMedium,
                                ),
                                TextButton(
                                  onPressed: _loadTickets,
                                  child: const Text(SupportTicketStrings.retry),
                                ),
                              ],
                            ),
                          if (_query.trim().isNotEmpty)
                            Text(
                              SupportTicketStrings.resultCount(filtered.length),
                              style: AppTextStyles.bodySmall,
                            ),
                        ],
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
                else if (_error != null && !_hasLoaded)
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
                      title: _query.trim().isNotEmpty
                          ? SupportTicketStrings.noResults
                          : widget.monitoring &&
                                _scope == SupportQueueScope.active
                          ? SupportMonitoringStrings.empty
                          : SupportTicketStrings.queueEmpty,
                      subtitle: _query.trim().isNotEmpty
                          ? SupportTicketStrings.noResultsHint
                          : widget.monitoring &&
                                _scope == SupportQueueScope.active
                          ? SupportMonitoringStrings.emptyHint
                          : SupportTicketStrings.queueEmptyHint,
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: SupportTicketQueueHeading(),
                    ),
                  ),
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
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, index) => SupportTicketCard(
                        ticket: filtered[index],
                        onTap: () => _openTicket(filtered[index]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
