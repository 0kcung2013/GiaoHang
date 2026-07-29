part of 'map_picker_sheet.dart';

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _MapHint extends StatelessWidget {
  const _MapHint({required this.isResolving});

  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.94),
        borderRadius: AppRadius.full,
        boxShadow: AppShadow.subtle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isResolving)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          else
            const Icon(
              Icons.open_with_rounded,
              size: 16,
              color: AppColors.accent,
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isResolving ? 'Đang đọc địa chỉ' : 'Di chuyển bản đồ để đặt ghim',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressConfirmationPanel extends StatelessWidget {
  const _AddressConfirmationPanel({
    required this.resolvedAddress,
    required this.isResolving,
    required this.resolutionError,
    required this.detailController,
    required this.detailError,
    required this.onDetailChanged,
    required this.onConfirm,
  });

  final ReverseGeocodeResult? resolvedAddress;
  final bool isResolving;
  final String? resolutionError;
  final TextEditingController detailController;
  final String? detailError;
  final ValueChanged<String> onDetailChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final hasHouseNumber = resolvedAddress?.hasHouseNumber == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isResolving
                  ? 'Đang xác định địa chỉ...'
                  : resolvedAddress?.displayAddress ?? 'Chưa có địa chỉ',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              resolutionError ??
                  (hasHouseNumber
                      ? 'Đã nhận diện số nhà ${resolvedAddress!.houseNumber}. Bạn có thể thêm tầng hoặc cổng.'
                      : 'Bản đồ chưa có số nhà. Hãy bổ sung để tài xế tìm chính xác.'),
              style: AppTextStyles.bodySmall.copyWith(
                color: resolutionError == null
                    ? AppColors.textSecondary
                    : AppColors.warning,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: detailController,
              onChanged: onDetailChanged,
              textInputAction: TextInputAction.done,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: hasHouseNumber
                    ? 'Tầng, căn hộ hoặc cổng (không bắt buộc)'
                    : 'Số nhà, tòa nhà, hẻm hoặc mốc gần đó',
                hintText: hasHouseNumber
                    ? 'Ví dụ: Tầng 3, cổng B'
                    : 'Ví dụ: 25A, hẻm 120, cạnh nhà thuốc',
                errorText: detailError,
                prefixIcon: const Icon(Icons.edit_location_alt_rounded),
                filled: true,
                fillColor: AppColors.bgLight,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: isResolving ? null : onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textPrimary,
                  disabledBackgroundColor: AppColors.border,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lg,
                  ),
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  'Xác nhận vị trí',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
