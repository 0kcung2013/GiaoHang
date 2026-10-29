import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../account/utils/customer_wallet_period.dart';
import 'data/customer_payment_repository.dart';
import 'dialogs/payment_detail_sheet.dart';
import 'models/customer_payment.dart';
import 'models/customer_payment_statistics.dart';
import 'payment_strings.dart';
import 'providers/customer_payment_providers.dart';
import 'widgets/payment_period_controls.dart';
import 'widgets/payment_surfaces.dart';
import 'widgets/payment_transaction_tile.dart';
import 'widgets/payment_trend_chart.dart';

class CustomerPaymentStatisticsScreen extends ConsumerStatefulWidget {
  const CustomerPaymentStatisticsScreen({super.key, this.today});
  final DateTime? today;
  @override
  ConsumerState<CustomerPaymentStatisticsScreen> createState() =>
      _CustomerPaymentStatisticsScreenState();
}

class _CustomerPaymentStatisticsScreenState
    extends ConsumerState<CustomerPaymentStatisticsScreen> {
  late final _today = widget.today ?? VietnamTime.now();
  late var _selection = CustomerWalletPeriodSelection(
    period: CustomerWalletPeriod.month,
    anchorDate: _today,
  );
  CustomerPaymentMethod? _method;
  int _visibleCount = 5;
  CustomerPaymentRange get _range =>
      (start: _selection.start, end: _selection.endExclusive);

  void _select(CustomerWalletPeriodSelection selection) => setState(() {
    _selection = selection;
    _visibleCount = 5;
  });

  Future<void> _refresh() async {
    ref.invalidate(customerPaymentsProvider(_range));
    try {
      await ref.read(customerPaymentsProvider(_range).future);
    } catch (_) {
      /* The provider renders the error state. */
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selection.anchorDate,
      firstDate: DateTime(2020),
      lastDate: _today,
      helpText: PaymentStrings.pickDate,
      cancelText: PaymentStrings.cancel,
      confirmText: PaymentStrings.choose,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      _select(
        CustomerWalletPeriodSelection(
          period: _selection.period,
          anchorDate: date,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(customerPaymentsProvider(_range));
    final titleStyle = AppTextStyles.headingMedium;
    final titleSize = MediaQuery.textScalerOf(
      context,
    ).scale(titleStyle.fontSize!);
    final currentPeriod = CustomerWalletPeriodSelection(
      period: _selection.period,
      anchorDate: _today,
    );
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        foregroundColor: AppColors.primary,
        toolbarHeight: titleSize > 24
            ? titleSize * titleStyle.height! * 2 + AppSpacing.lg
            : kToolbarHeight,
        title: Text(PaymentStrings.title, style: titleStyle, maxLines: 2),
        actions: [
          IconButton(
            onPressed: () => showPaymentExplanation(context),
            tooltip: PaymentStrings.explanation,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaymentPeriodControls(
                      selection: _selection,
                      today: _today,
                      method: _method,
                      onPeriod: (period) =>
                          _select(_selection.withPeriod(period)),
                      onMethod: (method) => setState(() {
                        _method = method;
                        _visibleCount = 5;
                      }),
                      onPrevious: () => _select(_selection.shift(-1)),
                      onNext: _selection.start.isBefore(currentPeriod.start)
                          ? () => _select(_selection.shift(1))
                          : null,
                      onPickDate: _pickDate,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      PaymentStrings.createdDate,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    payments.when(
                      skipLoadingOnRefresh: false,
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                        child: LinearProgressIndicator(
                          color: AppColors.accent,
                          backgroundColor: AppColors.accentLight,
                          semanticsLabel: PaymentStrings.loading,
                        ),
                      ),
                      error: (_, _) =>
                          PaymentMessage(failed: true, onRetry: _refresh),
                      data: (rows) {
                        final statistics = CustomerPaymentStatistics(
                          rows,
                          method: _method,
                        );
                        if (statistics.payments.isEmpty) {
                          return const PaymentMessage();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PaymentSummary(statistics: statistics),
                            const SizedBox(height: AppSpacing.lg),
                            PaymentTrendChart(
                              buckets: statistics.buckets(_selection),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PaymentMethodBreakdown(statistics: statistics),
                            const SizedBox(height: AppSpacing.xl2),
                            Text(
                              PaymentStrings.transactions,
                              style: AppTextStyles.headingSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              PaymentStrings.count(statistics.payments.length),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            for (final payment in statistics.payments.take(
                              _visibleCount,
                            ))
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: PaymentTransactionTile(
                                  key: ValueKey(payment.key),
                                  payment: payment,
                                ),
                              ),
                            if (statistics.payments.length > _visibleCount)
                              OutlinedButton(
                                onPressed: () =>
                                    setState(() => _visibleCount += 20),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  minimumSize: const Size(48, 48),
                                ),
                                child: Text(
                                  PaymentStrings.showAll(
                                    statistics.payments.length,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
