import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/settings_fields.dart';
import '../settings_strings.dart';

class SettingsChanges extends StatelessWidget {
  const SettingsChanges({
    super.key,
    required this.before,
    required this.after,
    this.fields,
  });
  final Map<String, dynamic> before, after;
  final Iterable<SettingsField>? fields;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(SettingsStrings.changes, style: AppTextStyles.labelLarge),
      const SizedBox(height: AppSpacing.sm),
      if (before.containsKey('long_distance_threshold_m') !=
          after.containsKey('long_distance_threshold_m'))
        Text(
          '${before.containsKey('long_distance_threshold_m') ? SettingsStrings.legacyRate : SettingsStrings.singleRate} → ${after.containsKey('long_distance_threshold_m') ? SettingsStrings.legacyRate : SettingsStrings.singleRate}',
          style: AppTextStyles.bodySmall,
        ),
      for (final field
          in (fields ?? [...settingsFields, ..._legacyFields]).where(
            (f) => before[f.key] != after[f.key],
          ))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            '${field.label}: ${_value(field, before[field.key])} → ${_value(field, after[field.key])}',
            style: AppTextStyles.bodySmall,
          ),
        ),
    ],
  );

  String _value(SettingsField field, Object? value) => value == null
      ? '—'
      : '${value is num ? field.display(value) : value} ${field.unit}'.trim();
}

const _legacyFields = [
  SettingsField(
    'long_distance_threshold_m',
    'Mốc đường dài (chính sách cũ)',
    unit: 'km',
    min: 100,
    max: 500000,
    divisor: 1000,
  ),
  SettingsField(
    'long_distance_per_km',
    'Giá/km đường dài (chính sách cũ)',
    unit: 'đ/km',
    min: 0,
    max: 100000,
  ),
];
