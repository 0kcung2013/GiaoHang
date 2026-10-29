import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/customer_dossier_strings.dart';
import '../data/customer_dossier_repository.dart';

/// Server-filtered, paginated data. Created only after its dossier tab is opened.
class CustomerDossierList<T> extends StatefulWidget {
  const CustomerDossierList({
    super.key,
    required this.load,
    required this.itemBuilder,
  });
  final Future<List<T>> Function(int offset) load;
  final Widget Function(T) itemBuilder;
  @override
  State<CustomerDossierList<T>> createState() => _CustomerDossierListState<T>();
}

class _CustomerDossierListState<T> extends State<CustomerDossierList<T>> {
  List<T> _rows = [];
  bool _loading = true, _failed = false, _hasMore = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await widget.load(more ? _rows.length : 0);
      if (!mounted || revision != _revision) return;
      setState(() {
        _hasMore = rows.length > SupabaseCustomerDossierRepository.pageSize;
        _rows = [
          if (more) ..._rows,
          ...rows.take(SupabaseCustomerDossierRepository.pageSize),
        ];
      });
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _failed = true);
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        if (_loading) const LinearProgressIndicator(color: AppColors.accent),
        if (_failed)
          Column(
            children: [
              Text(
                CustomerDossierStrings.error,
                style: AppTextStyles.bodyMedium,
              ),
              TextButton(
                onPressed: () => _load(more: _rows.isNotEmpty),
                child: const Text(CustomerDossierStrings.retry),
              ),
            ],
          ),
        if (!_loading && !_failed && _rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              CustomerDossierStrings.empty,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        for (final row in _rows) ...[
          widget.itemBuilder(row),
          const Divider(color: AppColors.border),
        ],
        if (_hasMore && !_loading)
          TextButton(
            onPressed: () => _load(more: true),
            child: const Text(CustomerDossierStrings.more),
          ),
      ],
    ),
  );
}
