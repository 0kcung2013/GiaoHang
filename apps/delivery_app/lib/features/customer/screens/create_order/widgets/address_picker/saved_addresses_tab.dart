import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../../core/models/saved_address_model.dart';
import '../../../../../../core/providers/address_providers.dart';
import '../../address_picker_strings.dart';
import 'address_list_item.dart';
import 'address_picker_states.dart';

enum SavedAddressAction { edit, setDefault, delete }

class SavedAddressesTab extends ConsumerWidget {
  const SavedAddressesTab({
    super.key,
    required this.userId,
    required this.onSelect,
    required this.onAdd,
    required this.onAction,
    this.busyAddressId,
  });

  final String userId;
  final ValueChanged<SavedAddressModel> onSelect;
  final VoidCallback onAdd;
  final void Function(SavedAddressModel, SavedAddressAction) onAction;
  final String? busyAddressId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(savedAddressesProvider(userId));
    return addresses.when(
      loading: () => const AddressLoadingList(),
      error: (_, _) => AddressErrorState(
        onRetry: () => ref.invalidate(savedAddressesProvider(userId)),
      ),
      data: (snapshot) {
        if (snapshot.items.isEmpty) {
          return AddressEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: AddressPickerStrings.noSavedTitle,
            description: AddressPickerStrings.noSavedDescription,
            actionLabel: AddressPickerStrings.addNewAddress,
            onAction: onAdd,
          );
        }

        final headerCount = snapshot.isFromCache ? 2 : 1;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xl3,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: snapshot.items.length + headerCount,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            if (index == 0) {
              return OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text(AddressPickerStrings.addNewAddress),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.accent),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.full,
                  ),
                ),
              );
            }
            if (index == 1 && snapshot.isFromCache) {
              return AddressCacheWarning(message: snapshot.warning ?? '');
            }

            final address = snapshot.items[index - headerCount];
            final isBusy = busyAddressId == address.id;
            return IgnorePointer(
              ignoring: isBusy,
              child: AnimatedOpacity(
                duration: AppDuration.fast,
                opacity: isBusy ? 0.62 : 1,
                child: AddressListItem(
                  icon: savedAddressIcon(address.labelType),
                  title: savedAddressLabel(address),
                  address: address.formattedAddress,
                  detail: address.addressDetail,
                  note: address.deliveryNote,
                  badge: address.isDefault
                      ? AddressPickerStrings.defaultLabel
                      : null,
                  onTap: () => onSelect(address),
                  trailing: isBusy
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.hourglass_top_rounded,
                            color: AppColors.accent,
                          ),
                        )
                      : PopupMenuButton<SavedAddressAction>(
                          tooltip: AddressPickerStrings.savedOptions,
                          onSelected: (action) => onAction(address, action),
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: AppColors.textSecondary,
                          ),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: SavedAddressAction.edit,
                              child: _MenuRow(
                                icon: Icons.edit_location_alt_rounded,
                                label: AddressPickerStrings.edit,
                              ),
                            ),
                            if (!address.isDefault)
                              const PopupMenuItem(
                                value: SavedAddressAction.setDefault,
                                child: _MenuRow(
                                  icon: Icons.star_rounded,
                                  label: AddressPickerStrings.setDefault,
                                ),
                              ),
                            const PopupMenuItem(
                              value: SavedAddressAction.delete,
                              child: _MenuRow(
                                icon: Icons.delete_outline_rounded,
                                label: AddressPickerStrings.delete,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: color)),
      ],
    );
  }
}
