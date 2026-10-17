import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../address_picker_strings.dart';
import '../../controllers/address_picker_controller.dart';

const addressPickerTabsKey = Key('address-picker-tabs');

class AddressPickerTabs extends StatelessWidget {
  const AddressPickerTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AddressPickerTab value;
  final ValueChanged<AddressPickerTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: addressPickerTabsKey,
      height: 50,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: AddressPickerTab.values
            .map((tab) {
              final selected = tab == value;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: _label(tab),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onChanged(tab),
                      borderRadius: AppRadius.md,
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.bgCard
                              : Colors.transparent,
                          borderRadius: AppRadius.md,
                          boxShadow: selected ? AppShadow.subtle : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _icon(tab),
                              size: 18,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                _label(tab),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: selected
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _label(AddressPickerTab tab) => switch (tab) {
    AddressPickerTab.map => AddressPickerStrings.mapTab,
    AddressPickerTab.saved => AddressPickerStrings.savedTab,
    AddressPickerTab.recent => AddressPickerStrings.recentTab,
  };

  IconData _icon(AddressPickerTab tab) => switch (tab) {
    AddressPickerTab.map => Icons.map_rounded,
    AddressPickerTab.saved => Icons.bookmark_rounded,
    AddressPickerTab.recent => Icons.history_rounded,
  };
}
