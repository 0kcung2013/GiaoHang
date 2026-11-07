import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../dispatch_preferences.dart';
import '../dispatch_preferences_providers.dart';
import '../dispatch_preferences_strings.dart';
import 'area_option_sheet.dart';
import 'dispatch_selection_field.dart';

class OperatingAreaFields extends ConsumerWidget {
  const OperatingAreaFields({
    super.key,
    required this.areaId,
    required this.onChanged,
    this.enabled = true,
  });
  final String? areaId;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(operatingAreasProvider)
      .when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: LinearProgressIndicator(),
        ),
        error: (_, _) => Column(
          children: [
            Text(
              DispatchPreferencesStrings.catalogError,
              style: AppTextStyles.bodyMedium,
            ),
            TextButton(
              onPressed: () => ref.invalidate(operatingAreasProvider),
              child: const Text(DispatchPreferencesStrings.retry),
            ),
          ],
        ),
        data: (areas) => _AreaSelectors(
          areas: areas,
          areaId: areaId,
          enabled: enabled,
          onChanged: onChanged,
        ),
      );
}

class _AreaSelectors extends StatefulWidget {
  const _AreaSelectors({
    required this.areas,
    required this.areaId,
    required this.onChanged,
    required this.enabled,
  });
  final List<OperatingArea> areas;
  final String? areaId;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  @override
  State<_AreaSelectors> createState() => _AreaSelectorsState();
}

class _AreaSelectorsState extends State<_AreaSelectors> {
  String? _province;
  @override
  void initState() {
    super.initState();
    for (final area in widget.areas) {
      if (area.id == widget.areaId) _province = area.provinceCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provinces = {
      for (final area in widget.areas) area.provinceCode: area.provinceName,
    };
    final districts = {
      for (final area in widget.areas.where((a) => a.provinceCode == _province))
        area.id: area.name,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provinces.isEmpty)
          Text(
            DispatchPreferencesStrings.catalogEmpty,
            style: AppTextStyles.bodyMedium,
          )
        else
          DispatchSelectionField(
            label: DispatchPreferencesStrings.province,
            icon: Icons.public_rounded,
            value:
                provinces[_province] ??
                DispatchPreferencesStrings.selectProvince,
            placeholder: _province == null,
            onTap: !widget.enabled
                ? null
                : () async {
                    final picked = await showAreaOptionSheet(
                      context,
                      title: DispatchPreferencesStrings.selectProvince,
                      options: provinces,
                      selected: _province,
                    );
                    if (picked != null && mounted && picked != _province) {
                      setState(() => _province = picked);
                      widget.onChanged(null);
                    }
                  },
          ),
        const SizedBox(height: AppSpacing.md),
        DispatchSelectionField(
          label: DispatchPreferencesStrings.district,
          icon: Icons.map_outlined,
          value:
              districts[widget.areaId] ??
              (_province == null
                  ? DispatchPreferencesStrings.selectProvinceFirst
                  : DispatchPreferencesStrings.selectArea),
          placeholder: !districts.containsKey(widget.areaId),
          onTap: !widget.enabled || districts.isEmpty
              ? null
              : () async {
                  final picked = await showAreaOptionSheet(
                    context,
                    title: DispatchPreferencesStrings.selectArea,
                    options: districts,
                    selected: widget.areaId,
                  );
                  if (picked != null && mounted) widget.onChanged(picked);
                },
        ),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          borderRadius: AppRadius.sm,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            useSafeArea: true,
            backgroundColor: AppColors.bgCard,
            builder: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl2,
                0,
                AppSpacing.xl2,
                AppSpacing.xl2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DispatchPreferencesStrings.catalogInfo,
                    style: AppTextStyles.headingMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    DispatchPreferencesStrings.legacyHint,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    DispatchPreferencesStrings.coverageHint,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    DispatchPreferencesStrings.legacyLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
