import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/saved_address_model.dart';
import '../../../../../core/providers/address_providers.dart';

/// Chip địa chỉ đã lưu — gán nhanh pickup / delivery.
class SavedAddressShortcuts extends ConsumerWidget {
  const SavedAddressShortcuts({
    super.key,
    required this.onApplyPickup,
    required this.onApplyDelivery,
  });

  final void Function(SavedAddressModel address) onApplyPickup;
  final void Function(SavedAddressModel address) onApplyDelivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentAddressUserIdProvider);
    if (userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(savedAddressesProvider(userId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (snapshot) {
        final addresses = snapshot.items;
        if (addresses.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accentLight.withValues(alpha: 0.55),
            borderRadius: AppRadius.xl,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: AppRadius.sm,
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.accent,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Địa chỉ dùng gần đây',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: addresses.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return _AddressChip(
                      address: address,
                      onPickup: () => onApplyPickup(address),
                      onDelivery: () => onApplyDelivery(address),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddressChip extends StatelessWidget {
  const _AddressChip({
    required this.address,
    required this.onPickup,
    required this.onDelivery,
  });

  final SavedAddressModel address;
  final VoidCallback onPickup;
  final VoidCallback onDelivery;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'pickup') onPickup();
        if (value == 'delivery') onDelivery();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'pickup',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.radio_button_checked_rounded,
              color: AppColors.markerPickup,
            ),
            title: Text('Dùng làm điểm lấy'),
          ),
        ),
        PopupMenuItem(
          value: 'delivery',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.location_on_rounded,
              color: AppColors.markerDrop,
            ),
            title: Text('Dùng làm điểm giao'),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.subtle,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              address.isDefault
                  ? Icons.home_rounded
                  : address.labelType == SavedAddressLabelType.work
                  ? Icons.work_outline_rounded
                  : Icons.bookmark_outline_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              _addressLabel(address),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

String _addressLabel(SavedAddressModel address) {
  return switch (address.labelType) {
    SavedAddressLabelType.home => 'Nhà',
    SavedAddressLabelType.work => 'Công ty',
    SavedAddressLabelType.warehouse => 'Kho hàng',
    SavedAddressLabelType.other => address.customLabel ?? 'Địa chỉ',
  };
}
