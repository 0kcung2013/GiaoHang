import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../settings_strings.dart';
import '../utils/pricing_explanation.dart';

class PricingSimulator extends StatefulWidget {
  const PricingSimulator({
    super.key,
    required this.settings,
    this.enabled = true,
  });
  final BusinessSettings? settings;
  final bool enabled;
  @override
  State<PricingSimulator> createState() => _PricingSimulatorState();
}

class _PricingSimulatorState extends State<PricingSimulator> {
  final _distance = TextEditingController(text: '5');
  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final km = double.tryParse(_distance.text.trim().replaceAll(',', '.'));
    final valid = km != null && km.isFinite && km >= 0 && km <= 2000;
    final fee = settings != null && valid
        ? DeliveryPricingPolicy.calculate(
            distanceMeters: km * 1000,
            settings: settings,
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(SettingsStrings.simulator, style: AppTextStyles.headingSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          settings == null
              ? SettingsStrings.pricingInvalid
              : explainPricing(settings),
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(SettingsStrings.distance, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: SettingsStrings.distance,
          child: TextFormField(
            key: const ValueKey('pricing-distance'),
            controller: _distance,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.bodyMedium,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              suffixText: 'km',
              errorText: valid ? null : SettingsStrings.distanceError,
              errorMaxLines: 3,
              filled: true,
              fillColor: AppColors.bgLight,
              border: const OutlineInputBorder(borderRadius: AppRadius.md),
            ),
          ),
        ),
        if (fee != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _FeeLine(label: SettingsStrings.baseFee, value: fee.baseFee),
          if (fee.standardBillableKm > 0)
            _FeeLine(
              label:
                  '${formatPricingKm(fee.standardBillableKm)} km vượt gói × ${formatVnd(fee.standardPerKm)}/km',
              value: fee.standardDistanceFee,
            )
          else
            Text(SettingsStrings.includedOnly, style: AppTextStyles.bodySmall),
          _FeeLine(
            label: SettingsStrings.rounding,
            value: fee.roundingAdjustment,
          ),
          const Divider(color: AppColors.border),
          Semantics(
            liveRegion: true,
            child: _FeeLine(
              label: SettingsStrings.total,
              value: fee.total,
              prominent: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Phí hoàn tham khảo: ${formatVnd(settings!.returnFee(fee.total))}. Đơn vị vận hành chi trả.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _FeeLine extends StatelessWidget {
  const _FeeLine({
    required this.label,
    required this.value,
    this.prominent = false,
  });
  final String label;
  final double value;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        Text(
          label,
          style: prominent ? AppTextStyles.labelLarge : AppTextStyles.bodySmall,
        ),
        Text(
          formatVnd(value),
          style: prominent
              ? AppTextStyles.headingMedium
              : AppTextStyles.labelMedium,
        ),
      ],
    ),
  );
}
