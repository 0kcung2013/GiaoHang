import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../settings_strings.dart';

class PricingImpactComparison extends StatelessWidget {
  const PricingImpactComparison({
    super.key,
    required this.before,
    required this.after,
    this.showHeading = true,
  });
  final BusinessSettings before, after;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final km in [3, 10, 20])
        (
          km: km,
          oldPrice: DeliveryPricingPolicy.calculate(
            distanceMeters: km * 1000,
            settings: before,
          ).total.round(),
          newPrice: DeliveryPricingPolicy.calculate(
            distanceMeters: km * 1000,
            settings: after,
          ).total.round(),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          Text(SettingsStrings.comparison, style: AppTextStyles.headingSmall),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(SettingsStrings.effectiveHint, style: AppTextStyles.bodySmall),
        if (CargoPricingPolicy.supported(before) ||
            CargoPricingPolicy.supported(after))
          Text(
            'Bảng quãng đường chưa gồm phụ phí hàng. Ví dụ kiện hàng ở bên dưới.',
            style: AppTextStyles.bodySmall,
          ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 640 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
              return Table(
                columnWidths: const {0: FlexColumnWidth(.6)},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      for (final label in [
                        'Quãng đường',
                        SettingsStrings.oldPrice,
                        SettingsStrings.newPrice,
                        SettingsStrings.difference,
                      ])
                        _Cell(label, header: true),
                    ],
                  ),
                  for (final row in rows)
                    TableRow(
                      children: [
                        _Cell('${row.km} km'),
                        _Cell(formatVnd(row.oldPrice)),
                        _Cell(formatVnd(row.newPrice)),
                        _Cell(_difference(row.newPrice - row.oldPrice)),
                      ],
                    ),
                ],
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: AppRadius.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${row.km} km', style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${SettingsStrings.oldPrice}: ${formatVnd(row.oldPrice)}',
                          style: AppTextStyles.bodySmall,
                        ),
                        Text(
                          '${SettingsStrings.newPrice}: ${formatVnd(row.newPrice)}',
                          style: AppTextStyles.bodySmall,
                        ),
                        Text(
                          _difference(row.newPrice - row.oldPrice),
                          style: AppTextStyles.labelMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (CargoPricingPolicy.supported(before) ||
            CargoPricingPolicy.supported(after)) ...[
          const SizedBox(height: AppSpacing.md),
          for (final (weight, size) in [
            (1.0, CargoSizeGroup.standard),
            (7.0, CargoSizeGroup.large),
            (12.0, CargoSizeGroup.extraLarge),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '5 km · $weight kg · kích thước ${size.label}: '
                '${_cargoPrice(before, weight, size)} → ${_cargoPrice(after, weight, size)}',
                style: AppTextStyles.bodySmall,
              ),
            ),
        ],
      ],
    );
  }

  String _difference(int delta) => delta == 0
      ? SettingsStrings.unchanged
      : '${delta > 0 ? 'Tăng' : 'Giảm'} ${formatVnd(delta.abs())}';

  String _cargoPrice(
    BusinessSettings settings,
    double weight,
    CargoSizeGroup size,
  ) {
    try {
      return formatVnd(
        DeliveryPricingPolicy.calculate(
          distanceMeters: 5000,
          settings: settings,
          weightKg: weight,
          cargo: CargoDetails(sizeGroup: size),
        ).total,
      );
    } on FormatException {
      return 'Vượt giới hạn';
    }
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.header = false});
  final String text;
  final bool header;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.sm,
      horizontal: AppSpacing.xs,
    ),
    child: Text(
      text,
      style: header ? AppTextStyles.labelMedium : AppTextStyles.bodySmall,
    ),
  );
}
