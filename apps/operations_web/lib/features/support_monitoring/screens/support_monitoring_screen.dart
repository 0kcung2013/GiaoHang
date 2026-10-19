import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/widgets/support_workspace_scaffold.dart';
import '../constants/journey_strings.dart';
import '../data/journey_archive_repository.dart';
import '../data/cached_journey_archive_repository.dart';
import '../models/archived_journey_order.dart';
import '../widgets/journey_archive_header.dart';
import '../widgets/journey_detail_panel.dart';
import '../widgets/journey_empty_state.dart';
import '../widgets/journey_filters.dart';
import '../widgets/journey_order_card.dart';

class SupportMonitoringScreen extends StatefulWidget {
  const SupportMonitoringScreen({
    this.repository,
    this.tileProvider,
    this.onCases,
    super.key,
  });
  final JourneyArchiveRepository? repository;
  final TileProvider? tileProvider;
  final VoidCallback? onCases;
  @override
  State<SupportMonitoringScreen> createState() =>
      _SupportMonitoringScreenState();
}

class _SupportMonitoringScreenState extends State<SupportMonitoringScreen> {
  late final _repository = CachedJourneyArchiveRepository(
    widget.repository ??
        R2JourneyArchiveRepository(
          client: Supabase.instance.client,
          storage: R2MediaClient.supabase(),
        ),
  );
  final _detailKeys = <String, GlobalKey>{};
  final _search = TextEditingController();
  List<ArchivedJourneyOrder> _archives = [];
  String? _selectedId;
  bool _loading = true;
  bool _failed = false;
  int _version = 0;
  int? _days = 14;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_version;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await _repository.fetchArchives();
      if (!mounted || version != _version) return;
      setState(() {
        _archives = items;
        if (!items.any((item) => item.order.id == _selectedId)) {
          _selectedId = null;
        }
      });
    } catch (_) {
      if (mounted && version == _version) setState(() => _failed = true);
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  List<ArchivedJourneyOrder> get _filtered {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final from = _range?.start ?? today.subtract(Duration(days: _days ?? 14));
    final through = _range?.end ?? today;
    return _archives
        .where(
          (item) =>
              item.matches(_search.text) &&
              !item.archive.lastDay.isBefore(from) &&
              !item.archive.firstDay.isAfter(through),
        )
        .toList();
  }

  Future<void> _chooseDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 14)),
      lastDate: today,
      initialDateRange: _range,
      helpText: JourneyStrings.dates,
    );
    if (range != null && mounted) {
      setState(() {
        _days = null;
        _range = DateTimeRange(
          start: DateTime.utc(
            range.start.year,
            range.start.month,
            range.start.day,
          ),
          end: DateTime.utc(range.end.year, range.end.month, range.end.day),
        );
        _selectedId = null;
      });
    }
  }

  Widget _filters() => JourneyFilters(
    controller: _search,
    onQuery: (_) => setState(() => _selectedId = null),
    days: _days,
    onDays: (days) => setState(() {
      _days = days;
      _range = null;
      _selectedId = null;
    }),
    onDateRange: _chooseDates,
    rangeLabel: _range == null
        ? null
        : '${_range!.start.day}/${_range!.start.month} – ${_range!.end.day}/${_range!.end.month}',
  );

  Widget _detail(ArchivedJourneyOrder item) => JourneyDetailPanel(
    key: _detailKeys.putIfAbsent(item.order.id, () => GlobalKey()),
    item: item,
    repository: _repository,
    onInvalidate: () => _repository.invalidate(item.order.id),
    tileProvider: widget.tileProvider,
  );

  Widget _state() {
    if (_loading && _archives.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.info),
      );
    }
    return JourneyEmptyState(
      title: _failed
          ? JourneyStrings.loadError
          : _archives.isEmpty
          ? JourneyStrings.empty
          : JourneyStrings.noResults,
      subtitle: _failed
          ? null
          : _archives.isEmpty
          ? JourneyStrings.emptyHint
          : JourneyStrings.noResultsHint,
      onRetry: _failed ? _load : null,
    );
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceScaffold(
    activeSection: SupportWorkspaceSection.monitoring,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 900 && constraints.maxHeight >= 500;
        final items = _filtered;
        final selected = items
            .where((item) => item.order.id == _selectedId)
            .firstOrNull;
        final header = JourneyArchiveHeader(
          onCases:
              widget.onCases ?? () => context.push('/support-monitoring/cases'),
          onRefresh: _loading ? null : _load,
        );
        if (!wide && selected != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('journey-back'),
                  onPressed: () => setState(() => _selectedId = null),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text(JourneyStrings.back),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: _detail(selected),
                ),
              ),
            ],
          );
        }
        final list = SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, index) => JourneyOrderCard(
            item: items[index],
            selected: items[index].order.id == _selectedId,
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => _selectedId = items[index].order.id);
            },
          ),
        );
        final catalog = CustomScrollView(
          key: const Key('journey-catalog'),
          slivers: [
            if (!wide) SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
              sliver: SliverToBoxAdapter(child: _filters()),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.xl2),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      JourneyStrings.results(items.length),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: LinearProgressIndicator(color: AppColors.info),
                      ),
                    if (_failed && _archives.isNotEmpty)
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(JourneyStrings.loadError),
                      ),
                  ],
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _state())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl2,
                  0,
                  AppSpacing.xl2,
                  AppSpacing.xl2,
                ),
                sliver: list,
              ),
          ],
        );
        if (!wide) return catalog;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: catalog),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        0,
                        AppSpacing.xl2,
                        AppSpacing.xl2,
                      ),
                      child: selected == null
                          ? Container(
                              decoration: BoxDecoration(
                                color: AppColors.bgCard,
                                borderRadius: AppRadius.lg,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const JourneyEmptyState(
                                title: JourneyStrings.choose,
                                subtitle: JourneyStrings.chooseHint,
                              ),
                            )
                          : _detail(selected),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
