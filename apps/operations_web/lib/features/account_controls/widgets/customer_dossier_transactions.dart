import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../support_orders/data/support_order_repository.dart';
import '../../support_transactions/data/transaction_repository.dart';
import '../../support_transactions/dialogs/transaction_detail_dialog.dart';
import '../../support_transactions/models/support_transaction.dart';
import '../../support_transactions/utils/transaction_ui.dart';
import '../constants/customer_dossier_strings.dart';
import '../data/customer_dossier_repository.dart';

class CustomerDossierTransactions extends StatefulWidget {
  const CustomerDossierTransactions({
    super.key,
    required this.userId,
    required this.repository,
    required this.transactionRepository,
    required this.orderRepository,
  });
  final String userId;
  final CustomerDossierRepository repository;
  final TransactionRepository transactionRepository;
  final SupportOrderRepository orderRepository;
  @override
  State<CustomerDossierTransactions> createState() =>
      _CustomerDossierTransactionsState();
}

class _CustomerDossierTransactionsState
    extends State<CustomerDossierTransactions> {
  TransactionGroup _group = TransactionGroup.payments;
  List<SupportTransaction> _rows = [];
  SupportTransaction? _cursor;
  DateTime? _serverNow;
  bool _loading = true, _hasMore = false, _failed = false;
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
      final page = await widget.repository.transactions(
        widget.userId,
        _group,
        before: more ? _cursor : null,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        // Staff search is fuzzy. Enforce an exact owner match before display,
        // keeping the server's raw cursor to avoid dropping matching later pages.
        final matches = page.rows.where((row) => row.userId == widget.userId);
        _rows = {
          for (final row in [if (more) ..._rows, ...matches]) row.key: row,
        }.values.toList();
        _cursor = page.rows.lastOrNull;
        _serverNow = page.serverNow;
        _hasMore = page.hasMore;
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CustomerDossierStrings.transactionHint,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final group in TransactionGroup.values)
                  ChoiceChip(
                    label: Text(TransactionUi.group(group)),
                    selected: _group == group,
                    selectedColor: AppColors.accentLight,
                    onSelected: (_) {
                      if (_group == group) return;
                      setState(() {
                        _group = group;
                        _rows = [];
                        _cursor = null;
                      });
                      _load();
                    },
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_loading) const LinearProgressIndicator(color: AppColors.accent),
        if (_failed) ...[
          Text(CustomerDossierStrings.error, style: AppTextStyles.bodyMedium),
          TextButton(
            onPressed: () => _load(more: _rows.isNotEmpty),
            child: const Text(CustomerDossierStrings.retry),
          ),
        ],
        if (!_loading && !_failed && _rows.isEmpty)
          Text(CustomerDossierStrings.empty, style: AppTextStyles.bodyMedium),
        for (final transaction in _rows)
          ListTile(
            title: Text(
              TransactionUi.kind(transaction),
              style: AppTextStyles.labelLarge,
            ),
            subtitle: Text(
              '${TransactionUi.money(transaction.amount)} · ${TransactionUi.status(transaction.status)}\n${transaction.displayReference}',
              style: AppTextStyles.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => TransactionDetailDialog(
                transaction: transaction,
                repository: widget.transactionRepository,
                orderRepository: widget.orderRepository,
                serverNow: _serverNow!,
              ),
            ),
          ),
        if (_hasMore && !_loading)
          TextButton(
            onPressed: () => _load(more: true),
            child: const Text(CustomerDossierStrings.more),
          ),
      ],
    ),
  );
}
