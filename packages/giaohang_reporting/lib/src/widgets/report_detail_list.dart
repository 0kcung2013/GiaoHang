import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../business_report_strings.dart';
import '../utils/report_format.dart';
import 'report_surface.dart';

class ReportDetailList extends StatefulWidget {
  const ReportDetailList({
    super.key,
    required this.report,
    required this.movements,
    this.staffView = false,
  });
  final BusinessReport report;
  final bool movements, staffView;
  @override
  State<ReportDetailList> createState() => _ReportDetailListState();
}

class _ReportDetailListState extends State<ReportDetailList> {
  int _visible = 20;

  String get _expenseLabel => widget.staffView
      ? BusinessReportStrings.senderCharges
      : BusinessReportStrings.expenseShort;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final count = widget.movements
        ? report.movements.length
        : report.orders.length;
    if (count == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl3),
        child: Text(
          BusinessReportStrings.empty,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 720 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  56,
                  AppSpacing.md,
                ),
                child: _columns([
                  widget.movements
                      ? BusinessReportStrings.kind
                      : BusinessReportStrings.code,
                  widget.movements
                      ? BusinessReportStrings.code
                      : BusinessReportStrings.status,
                  BusinessReportStrings.date,
                  widget.movements
                      ? BusinessReportStrings.amount
                      : _expenseLabel,
                ], header: true),
              ),
            ReportSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < count && i < _visible; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
                    if (widget.movements)
                      _movement(report.movements[i], wide)
                    else
                      _order(report.orders[i], wide),
                  ],
                ],
              ),
            ),
            if (_visible < count) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                ),
                onPressed: () => setState(() => _visible += 20),
                child: const Text(BusinessReportStrings.more),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _order(BusinessReportOrder order, bool wide) => _expandable(
    key: ValueKey(order.id),
    title: wide
        ? _columns([
            order.code,
            BusinessReportStrings.orderStatus(order.status),
            reportDay(VietnamTime.toWallClock(order.eventAt)),
            formatVnd(order.senderCharge),
          ])
        : _compact(
            title: order.code,
            contextLabel: BusinessReportStrings.orderStatus(order.status),
            date: order.eventAt,
            amount: order.senderCharge,
            amountLabel: _expenseLabel,
          ),
    children: [
      ReportLabelValue(
        label: BusinessReportStrings.date,
        value: reportDate(order.eventAt),
      ),
      ReportLabelValue(
        label: BusinessReportStrings.cod,
        value: formatVnd(order.cod),
      ),
      ReportLabelValue(
        label: BusinessReportStrings.deliveryFee,
        value: formatVnd(order.deliveryFee),
      ),
      ReportLabelValue(
        label: BusinessReportStrings.platformFee,
        value: formatVnd(order.platformFee),
      ),
      if (order.status == 'returned')
        ReportLabelValue(
          label: BusinessReportStrings.returnFee,
          value: formatVnd(order.settledReturnCharge),
        ),
      ReportLabelValue(
        label: BusinessReportStrings.recipientCharges,
        value: formatVnd(order.recipientCharge),
      ),
      if (order.status != 'delivered')
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            BusinessReportStrings.costBasis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
    ],
  );

  Widget _movement(BusinessReportMovement movement, bool wide) => _expandable(
    key: ValueKey(movement.id),
    title: wide
        ? _columns([
            BusinessReportStrings.movement(movement.kind),
            movement.code ?? BusinessReportStrings.noLinkedOrder,
            reportDay(VietnamTime.toWallClock(movement.eventAt)),
            _signedAmount(movement.amount),
          ])
        : _compact(
            title: BusinessReportStrings.movement(movement.kind),
            contextLabel: movement.code ?? BusinessReportStrings.noLinkedOrder,
            date: movement.eventAt,
            amount: movement.amount,
            signed: true,
          ),
    children: [
      ReportLabelValue(
        label: BusinessReportStrings.date,
        value: reportDate(movement.eventAt),
      ),
      ReportLabelValue(
        label: BusinessReportStrings.state,
        value: BusinessReportStrings.paymentState(movement.paymentState),
      ),
      ReportLabelValue(
        label: BusinessReportStrings.reference,
        value: movement.id,
      ),
    ],
  );

  String _signedAmount(int amount) =>
      '${amount > 0 ? '+' : ''}${formatVnd(amount)}';

  Widget _columns(List<String> values, {bool header = false}) => Row(
    children: [
      for (var i = 0; i < values.length; i++)
        Expanded(
          flex: i == 0 ? 3 : 2,
          child: Padding(
            padding: EdgeInsets.only(right: i == 3 ? 0 : AppSpacing.md),
            child: Text(
              values[i],
              textAlign: i == 3 ? TextAlign.right : TextAlign.left,
              style: header
                  ? AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    )
                  : AppTextStyles.labelMedium,
            ),
          ),
        ),
    ],
  );

  Widget _compact({
    required String title,
    required String contextLabel,
    required DateTime date,
    required int amount,
    String? amountLabel,
    bool signed = false,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 270 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                reportDay(VietnamTime.toWallClock(date)),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                contextLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      );
      final money = Column(
        crossAxisAlignment: stacked
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            signed ? _signedAmount(amount) : formatVnd(amount),
            style: AppTextStyles.labelLarge.copyWith(
              color: signed && amount > 0
                  ? AppColors.success
                  : AppColors.primary,
            ),
          ),
          if (amountLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              amountLabel,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            identity,
            const SizedBox(height: AppSpacing.sm),
            money,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: identity),
          const SizedBox(width: AppSpacing.md),
          Flexible(flex: 2, child: money),
        ],
      );
    },
  );

  Widget _expandable({
    required Key key,
    required Widget title,
    required List<Widget> children,
  }) => ExpansionTile(
    key: key,
    tilePadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    childrenPadding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    shape: const Border(),
    collapsedShape: const Border(),
    backgroundColor: AppColors.bgCard,
    collapsedBackgroundColor: AppColors.bgCard,
    iconColor: AppColors.primary,
    collapsedIconColor: AppColors.textSecondary,
    textColor: AppColors.textPrimary,
    collapsedTextColor: AppColors.textPrimary,
    title: title,
    children: children,
  );
}
