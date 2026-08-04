import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../../core/models/recent_address_model.dart';
import '../../../../../../core/providers/address_providers.dart';
import '../../address_picker_strings.dart';
import 'address_list_item.dart';
import 'address_picker_states.dart';

class RecentAddressesTab extends ConsumerWidget {
  const RecentAddressesTab({
    super.key,
    required this.userId,
    required this.onSelect,
    required this.onSave,
    required this.onDelete,
    required this.onClear,
    this.busyAddressId,
    this.isClearing = false,
  });

  final String userId;
  final ValueChanged<RecentAddressModel> onSelect;
  final ValueChanged<RecentAddressModel> onSave;
  final ValueChanged<RecentAddressModel> onDelete;
  final VoidCallback onClear;
  final String? busyAddressId;
  final bool isClearing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(recentAddressesProvider(userId));
    return addresses.when(
      loading: () => const AddressLoadingList(),
      error: (_, _) => AddressErrorState(
        onRetry: () => ref.invalidate(recentAddressesProvider(userId)),
      ),
      data: (snapshot) {
        if (snapshot.items.isEmpty) {
          return const AddressEmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: AddressPickerStrings.noRecentTitle,
            description: AddressPickerStrings.noRecentDescription,
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
          itemCount: snapshot.items.length + headerCount,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      AddressPickerStrings.recentLimit,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: isClearing ? null : onClear,
                    icon: Icon(
                      isClearing
                          ? Icons.hourglass_top_rounded
                          : Icons.delete_sweep_outlined,
                      size: 18,
                    ),
                    label: const Text(AddressPickerStrings.clearHistory),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              );
            }
            if (snapshot.isFromCache && index == 1) {
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
                  icon: address.addressType == RecentAddressType.pickup
                      ? Icons.radio_button_checked_rounded
                      : Icons.location_on_rounded,
                  accentColor: address.addressType == RecentAddressType.pickup
                      ? AppColors.markerPickup
                      : AppColors.markerDrop,
                  title: _recentTitle(address),
                  address: address.formattedAddress,
                  detail: address.addressDetail,
                  note: _usageText(address),
                  onTap: () => onSelect(address),
                  trailing: SizedBox(
                    width: 48,
                    child: PopupMenuButton<String>(
                      tooltip: AddressPickerStrings.recentOptions,
                      onSelected: (value) {
                        if (value == 'save') onSave(address);
                        if (value == 'delete') onDelete(address);
                      },
                      icon: Icon(
                        isBusy
                            ? Icons.hourglass_top_rounded
                            : Icons.more_vert_rounded,
                        color: isBusy
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'save',
                          child: _RecentMenuRow(
                            icon: Icons.bookmark_add_outlined,
                            label: AddressPickerStrings.saveAddress,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: _RecentMenuRow(
                            icon: Icons.delete_outline_rounded,
                            label: AddressPickerStrings.delete,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _recentTitle(RecentAddressModel address) {
    final type = address.addressType == RecentAddressType.pickup
        ? AddressPickerStrings.pickupShort
        : AddressPickerStrings.deliveryShort;
    return '$type · ${_relativeTime(address.lastUsedAt)}';
  }

  String _usageText(RecentAddressModel address) {
    return address.usageCount > 1
        ? 'Đã dùng ${address.usageCount} lần'
        : AddressPickerStrings.usedOnce;
  }

  String _relativeTime(DateTime value) {
    final now = DateTime.now();
    final local = value.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final days = today.difference(date).inDays;
    if (days <= 0) return AddressPickerStrings.today;
    if (days == 1) return AddressPickerStrings.yesterday;
    return '$days ngày trước';
  }
}

class _RecentMenuRow extends StatelessWidget {
  const _RecentMenuRow({
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
