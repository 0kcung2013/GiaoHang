import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/saved_address_model.dart';
import '../../../../../core/providers/customer_providers.dart';

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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(savedAddressesProvider(userId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (addresses) {
        if (addresses.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: AppRadius.sm,
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Chọn nhanh địa chỉ đã lưu',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
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
                  final a = addresses[index];
                  return _AddressChip(
                    address: a,
                    onPickup: () => onApplyPickup(a),
                    onDelivery: () => onApplyDelivery(a),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
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
              address.isDefaultPickup
                  ? Icons.home_rounded
                  : address.isDefaultDelivery
                  ? Icons.work_outline_rounded
                  : Icons.bookmark_outline_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              address.label.isEmpty ? 'Địa chỉ' : address.label,
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
