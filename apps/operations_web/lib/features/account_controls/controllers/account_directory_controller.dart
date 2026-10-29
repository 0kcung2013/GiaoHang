import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/account_control_repository.dart';
import '../models/staff_account.dart';

class AccountDirectoryController extends ChangeNotifier {
  AccountDirectoryController(
    this.repository, {
    this.search = '',
    this.disabledOnly = false,
  });
  final AccountControlRepository repository;
  List<StaffAccount> rows = [];
  String search;
  String? role;
  bool disabledOnly, loading = false, failed = false, hasMore = false;
  int page = 0, _generation = 0;
  bool _disposed = false;
  Timer? _debounce;
  void filter({String? query, String? roleValue, bool? disabled}) {
    _debounce?.cancel();
    if (query != null) search = query;
    if (roleValue != null) role = roleValue.isEmpty ? null : roleValue;
    if (disabled != null) disabledOnly = disabled;
    page = 0;
    // Invalidate in-flight replies immediately, including during debounce.
    ++_generation;
    rows = [];
    loading = true;
    failed = false;
    notifyListeners();
    if (query != null) {
      _debounce = Timer(const Duration(milliseconds: 350), load);
    } else {
      unawaited(load());
    }
  }

  Future<void> load() async {
    _debounce?.cancel();
    final generation = ++_generation;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final result = await repository.list(
        search: search,
        role: role,
        disabledOnly: disabledOnly,
        offset: page * SupabaseAccountControlRepository.pageSize,
      );
      if (_disposed || generation != _generation) return;
      rows = result.rows;
      hasMore = result.hasMore;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        failed = true;
        rows = [];
        hasMore = false;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void move(int delta) {
    if (loading || page + delta < 0 || (delta > 0 && !hasMore)) return;
    page += delta;
    unawaited(load());
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
