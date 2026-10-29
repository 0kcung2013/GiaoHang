import 'dart:async';
import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/admin_strings.dart';
import '../../data/admin_repository.dart';
import '../../models/admin_snapshot.dart';
import '../../widgets/admin_account_list.dart';
import '../../widgets/admin_surface.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key, this.repository});
  final AdminRepository? repository;
  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  late final _repository =
      widget.repository ?? SupabaseAdminRepository(Supabase.instance.client);
  final _search = TextEditingController();
  Timer? _debounce;
  final _scroll = ScrollController();
  List<AdminAccount> _accounts = [];
  bool _loading = true, _failed = false, _hasNext = false;
  String? _role;
  int _page = 0, _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await _repository.fetchAccounts(
        query: _search.text,
        role: _role,
        offset: _page * SupabaseAdminRepository.pageSize,
      );
      if (!mounted || version != _generation) return;
      setState(() {
        _hasNext = rows.length > SupabaseAdminRepository.pageSize;
        _accounts = rows.take(SupabaseAdminRepository.pageSize).toList();
      });
    } catch (_) {
      if (mounted && version == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && version == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: _scroll,
    padding: const EdgeInsets.all(AppSpacing.xl2),
    children: [
      AdminHeading(
        title: AdminStrings.usersTitle,
        subtitle: AdminStrings.usersReadOnly,
        action: OutlinedButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text(AdminStrings.refresh),
        ),
      ),
      const SizedBox(height: AppSpacing.xl2),
      TextField(
        controller: _search,
        decoration: const InputDecoration(
          labelText: AdminStrings.usersSearch,
          prefixIcon: Icon(Icons.search_rounded),
        ),
        onChanged: (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () {
            _page = 0;
            _load();
          });
        },
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final role in ['', 'customer', 'driver', 'support', 'admin'])
            ChoiceChip(
              label: Text(
                role.isEmpty ? AdminStrings.all : AdminStrings.roleLabel(role),
              ),
              selected: (_role ?? '') == role,
              onSelected: (_) {
                _role = role.isEmpty ? null : role;
                _page = 0;
                _load();
              },
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      if (_loading) const LinearProgressIndicator(color: AppColors.accent),
      if (_failed)
        AdminFailure(onRetry: _load)
      else if (!_loading && _accounts.isEmpty)
        const AdminSurface(child: Text(AdminStrings.usersEmpty))
      else
        IgnorePointer(
          ignoring: _loading,
          child: AdminAccountList(accounts: _accounts),
        ),
      const SizedBox(height: AppSpacing.lg),
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: _loading || _page == 0
                ? null
                : () {
                    _page--;
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                    _load();
                  },
            child: const Text(AdminStrings.previous),
          ),
          Text(AdminStrings.page(_page + 1)),
          OutlinedButton(
            onPressed: _loading || _failed || !_hasNext
                ? null
                : () {
                    _page++;
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                    _load();
                  },
            child: const Text(AdminStrings.next),
          ),
        ],
      ),
    ],
  );
}
