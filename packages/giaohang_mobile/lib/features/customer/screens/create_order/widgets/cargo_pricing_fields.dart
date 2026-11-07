import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import 'create_order_inputs.dart';
import '../../../../../core/utils/cargo_pricing_strings.dart';
export '../../../../../core/utils/cargo_pricing_strings.dart';

class CargoPricingFields extends StatelessWidget {
  const CargoPricingFields({
    super.key,
    required this.settings,
    required this.weightController,
    required this.countController,
    required this.sizeValue,
    required this.onSizeChanged,
  });

  final BusinessSettings settings;
  final TextEditingController weightController;
  final TextEditingController countController;
  final String sizeValue;
  final ValueChanged<String> onSizeChanged;

  String? _error() {
    if (sizeValue.isEmpty) return CargoPricingText.sizeRequired;
    if (sizeValue == 'oversized') return CargoPricingText.oversizedError;
    if (CargoSizeGroup.parse(sizeValue) == null) {
      return CargoPricingText.sizeRequired;
    }
    final weight = parseCargoWeightKg(weightController.text);
    if (weight != null &&
        weight * 1000 > settings.number('cargo_extra_large_weight_g')) {
      return CargoPricingText.weightLimit(
        settings.number('cargo_extra_large_weight_g') / 1000,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    CargoDetails? result;
    final weight = parseCargoWeightKg(weightController.text);
    final size = CargoSizeGroup.parse(sizeValue);
    final count = int.tryParse(countController.text);
    if (_error() == null &&
        weight != null &&
        isCargoWeightInput(weightController.text) &&
        size != null &&
        count != null &&
        count >= 1 &&
        count <= 100) {
      result = CargoPricingPolicy.calculate(
        settings: settings,
        weightKg: weight,
        declaration: CargoDetails(sizeGroup: size, packageCount: count),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CreateOrderTextField(
          key: const Key('cargo-package-count'),
          controller: countController,
          label: CargoPricingText.packageCount,
          hint: '1',
          icon: Icons.layers_outlined,
          keyboardType: TextInputType.number,
          validator: (value) {
            final n = int.tryParse(value?.trim() ?? '');
            return n != null && n >= 1 && n <= 100
                ? null
                : CargoPricingText.countError;
          },
          requiredField: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(CargoPricingText.size, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(CargoPricingText.sizeHint, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        FormField<String>(
          key: ValueKey('cargo-size-$sizeValue'),
          initialValue: sizeValue,
          validator: (_) => _error(),
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in CargoSizeGroup.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _SizeOption(
                    selected: sizeValue == group.databaseValue,
                    label: group.label,
                    detail: CargoPricingText.sizeLimit(
                      CargoPricingPolicy.dimensions(settings, group),
                    ),
                    onTap: () => onSizeChanged(group.databaseValue),
                  ),
                ),
              _SizeOption(
                selected: sizeValue == 'oversized',
                label: CargoPricingText.oversized,
                detail: CargoPricingText.oversizedError,
                onTap: () => onSizeChanged('oversized'),
              ),
              if (field.hasError || sizeValue == 'oversized')
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    field.errorText ?? CargoPricingText.oversizedError,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              '${result.tier!.label} · ${CargoPricingText.surcharge}: ${formatVnd(result.surcharge)}',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.tier!.index > result.sizeGroup.index
                ? CargoPricingText.byWeight(formatCargoWeightKg(weight))
                : CargoPricingText.bySize,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({
    required this.selected,
    required this.label,
    required this.detail,
    required this.onTap,
  });
  final bool selected;
  final String label, detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.accentLight : AppColors.bgLight,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.inventory_2_outlined,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.labelMedium),
                    Text(detail, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
