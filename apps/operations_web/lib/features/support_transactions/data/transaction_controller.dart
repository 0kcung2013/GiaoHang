import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/transaction_strings.dart';
import '../models/support_transaction.dart';
import 'transaction_repository.dart';

class TransactionController extends ChangeNotifier {
  TransactionController(this.repository);
  final TransactionRepository repository;
  TransactionGroup group = TransactionGroup.topups;
  String search = '', status = 'all';
  DateTime? from, to;
  List<SupportTransaction> rows = [];
  bool loading = false, loadingMore = false, hasMore = false;
  DateTime serverNow = DateTime.now();
  String? error;
  int _revision = 0;
  bool _disposed = false;
  Timer? _debounce;

  void changeGroup(TransactionGroup value) {
    if (value == group) return;
    group = value;
    status = 'all';
    _reset();
  }

  void changeSearch(String value) {
    search = value.trim();
    _reset(debounce: true);
  }

  void changeStatus(String value) {
    status = value;
    _reset();
  }

  void changeDates(DateTime? start, DateTime? end) {
    from = start;
    to = end;
    _reset();
  }

  void _reset({bool debounce = false}) {
    _debounce?.cancel();
    _revision++;
    rows = [];
    hasMore = false;
    error = null;
    loading = true;
    loadingMore = false;
    notifyListeners();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 350), refresh);
    } else {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    _debounce?.cancel();
    await _load(more: false);
  }

  Future<void> loadMore() async {
    if (!hasMore || loading || loadingMore) return;
    await _load(more: true);
  }

  Future<void> _load({required bool more}) async {
    final revision = more ? _revision : ++_revision;
    if (more) {
      loadingMore = true;
    } else {
      loading = true;
      loadingMore = false;
    }
    error = null;
    notifyListeners();
    try {
      final page = await repository.fetch(
        group: group,
        search: search,
        status: status,
        from: from,
        to: to,
        before: more && rows.isNotEmpty ? rows.last : null,
      );
      if (_disposed || revision != _revision) return;
      rows = more
          ? {
              for (final row in [...rows, ...page.rows]) row.key: row,
            }.values.toList()
          : page.rows;
      hasMore = page.hasMore;
      serverNow = page.serverNow;
    } catch (e) {
      if (_disposed || revision != _revision) return;
      error = e is PostgrestException && e.code == 'PGRST202'
          ? TransactionStrings.unavailable
          : TransactionStrings.error;
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _debounce?.cancel();
    super.dispose();
  }
}
