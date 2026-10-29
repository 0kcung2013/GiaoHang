import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support_orders/data/support_order_repository.dart';
import '../../support_transactions/data/transaction_repository.dart';
import '../constants/account_strings.dart';
import '../constants/customer_dossier_strings.dart';
import '../data/account_control_repository.dart';
import '../data/customer_dossier_repository.dart';
import '../models/staff_account.dart';
import '../widgets/account_list.dart';
import '../widgets/customer_dossier_activity.dart';
import '../widgets/customer_dossier_transactions.dart';
import 'account_history_dialog.dart';

enum CustomerDossierTab { overview, orders, transactions, support }

class CustomerDossierDialog extends StatefulWidget {
  const CustomerDossierDialog({
    super.key,
    required this.account,
    required this.accountRepository,
    required this.isAdmin,
    this.repository,
    this.orderRepository,
    this.transactionRepository,
    this.riskReportId,
    this.ticketId,
  });
  final StaffAccount account;
  final AccountControlRepository accountRepository;
  final bool isAdmin;
  final CustomerDossierRepository? repository;
  final SupportOrderRepository? orderRepository;
  final TransactionRepository? transactionRepository;
  final String? riskReportId, ticketId;
  @override
  State<CustomerDossierDialog> createState() => _CustomerDossierDialogState();
}

class _CustomerDossierDialogState extends State<CustomerDossierDialog> {
  CustomerDossierTab _tab = CustomerDossierTab.overview;
  final _visited = <CustomerDossierTab, Widget>{};
  late final _repository =
      widget.repository ??
      SupabaseCustomerDossierRepository(Supabase.instance.client);
  late final _orders =
      widget.orderRepository ??
      SupabaseSupportOrderRepository(Supabase.instance.client);
  late final _transactions =
      widget.transactionRepository ??
      SupabaseTransactionRepository(Supabase.instance.client);

  Future<void> _manage() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AccountHistoryDialog(
        account: widget.account,
        repository: widget.accountRepository,
        isAdmin: widget.isAdmin,
        riskReportId: widget.riskReportId,
        ticketId: widget.ticketId,
      ),
    );
    // Decisions close the snapshot and refresh the directory, including
    // ambiguous receipts. Never keep showing the old account state afterwards.
    if (mounted && result != null) Navigator.pop(context, result);
  }

  Widget _body(CustomerDossierTab tab) => switch (tab) {
    CustomerDossierTab.overview => ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          CustomerDossierStrings.accountHint,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final fact in [
          (CustomerDossierStrings.userId, widget.account.id),
          (CustomerDossierStrings.name, widget.account.name),
          (CustomerDossierStrings.email, widget.account.email),
          (CustomerDossierStrings.phone, widget.account.phone),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fact.$1, style: AppTextStyles.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  fact.$2?.isNotEmpty == true
                      ? fact.$2!
                      : CustomerDossierStrings.missing,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        AccountStatus(account: widget.account),
        const SizedBox(height: AppSpacing.md),
        Text(
          AccountStrings.activeOrders(widget.account.activeOrders),
          style: AppTextStyles.labelMedium,
        ),
      ],
    ),
    CustomerDossierTab.orders => CustomerDossierOrders(
      userId: widget.account.id,
      repository: _repository,
      orderRepository: _orders,
    ),
    CustomerDossierTab.transactions => CustomerDossierTransactions(
      userId: widget.account.id,
      repository: _repository,
      transactionRepository: _transactions,
      orderRepository: _orders,
    ),
    CustomerDossierTab.support => CustomerDossierTickets(
      userId: widget.account.id,
      repository: _repository,
      isAdmin: widget.isAdmin,
    ),
  };

  @override
  Widget build(BuildContext context) {
    _visited.putIfAbsent(_tab, () => _body(_tab));
    final tabs = _visited.keys.toList();
    return Dialog(
      backgroundColor: AppColors.bgCard,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: SizedBox(
          width: 980,
          height: 760,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        CustomerDossierStrings.title,
                        style: AppTextStyles.headingMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: CustomerDossierStrings.close,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.account.name,
                    style: AppTextStyles.headingSmall,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final tab in CustomerDossierTab.values)
                      ChoiceChip(
                        selected: _tab == tab,
                        selectedColor: AppColors.accentLight,
                        label: Text(switch (tab) {
                          CustomerDossierTab.overview =>
                            CustomerDossierStrings.overview,
                          CustomerDossierTab.orders =>
                            CustomerDossierStrings.orders,
                          CustomerDossierTab.transactions =>
                            CustomerDossierStrings.transactions,
                          CustomerDossierTab.support =>
                            CustomerDossierStrings.support,
                        }),
                        onSelected: (_) => setState(() => _tab = tab),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: IndexedStack(
                  index: tabs.indexOf(_tab),
                  children: tabs.map((t) => _visited[t]!).toList(),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _manage,
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text(CustomerDossierStrings.decisions),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
