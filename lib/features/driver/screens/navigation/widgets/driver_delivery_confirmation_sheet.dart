import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../models/driver_delivery_workflow.dart';
import 'driver_proof_photo_field.dart';

class DriverDeliveryConfirmationResult {
  const DriverDeliveryConfirmationResult({this.proofImage});

  final XFile? proofImage;
}

Future<DriverDeliveryConfirmationResult?> showDriverDeliveryConfirmationSheet({
  required BuildContext context,
  required DriverDeliveryAction action,
  required OrderModel order,
  CaptureProofPhoto? capturePhoto,
}) async {
  return showModalBottomSheet<DriverDeliveryConfirmationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DriverDeliveryConfirmationSheet(
      action: action,
      order: order,
      capturePhoto: capturePhoto,
    ),
  );
}

class _DriverDeliveryConfirmationSheet extends StatefulWidget {
  const _DriverDeliveryConfirmationSheet({
    required this.action,
    required this.order,
    this.capturePhoto,
  });

  final DriverDeliveryAction action;
  final OrderModel order;
  final CaptureProofPhoto? capturePhoto;

  @override
  State<_DriverDeliveryConfirmationSheet> createState() =>
      _DriverDeliveryConfirmationSheetState();
}

class _DriverDeliveryConfirmationSheetState
    extends State<_DriverDeliveryConfirmationSheet> {
  final Set<int> _checkedItems = {};
  XFile? _proofImage;

  bool get _requiresPhoto => widget.action.requiresProofPhoto;

  List<String> get _checklist {
    return switch (widget.action) {
      DriverDeliveryAction.startPickupJourney => const [],
      DriverDeliveryAction.confirmPickup => const [
        'Đã nhận đúng kiện hàng của đơn này',
        'Đã kiểm tra tình trạng bên ngoài của kiện hàng',
      ],
      DriverDeliveryAction.startDelivery => const [],
      DriverDeliveryAction.confirmDelivery => [
        'Đã giao đúng người nhận hoặc người được ủy quyền',
        if (widget.order.paymentMethod == 'cash')
          'Đã hoàn tất thu hộ và đối soát tiền mặt',
      ],
      DriverDeliveryAction.none => const [],
    };
  }

  bool get _canConfirm {
    final checklistComplete =
        _checklist.isEmpty || _checkedItems.length == _checklist.length;
    return checklistComplete && (!_requiresPhoto || _proofImage != null);
  }

  @override
  Widget build(BuildContext context) {
    final config = _config(widget.action);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadow.elevated,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        MediaQuery.of(context).viewPadding.bottom + AppSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: config.accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.lg,
                ),
                child: Icon(config.icon, color: config.accent, size: 28),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                config.title,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                config.description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (_requiresPhoto) ...[
                const SizedBox(height: AppSpacing.xl),
                DriverProofPhotoField(
                  accent: config.accent,
                  capturePhoto: widget.capturePhoto,
                  onChanged: (photo) => setState(() => _proofImage = photo),
                ),
              ],
              if (_checklist.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'XÁC NHẬN BÀN GIAO',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...List.generate(_checklist.length, (index) {
                  final checked = _checkedItems.contains(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ChecklistTile(
                      label: _checklist[index],
                      checked: checked,
                      onTap: () {
                        setState(() {
                          checked
                              ? _checkedItems.remove(index)
                              : _checkedItems.add(index);
                        });
                      },
                    ),
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.full,
                        ),
                      ),
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _canConfirm
                          ? () => Navigator.of(context).pop(
                              DriverDeliveryConfirmationResult(
                                proofImage: _proofImage,
                              ),
                            )
                          : null,
                      icon: Icon(config.icon, size: 19),
                      label: Text(config.confirmLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: config.accent,
                        disabledBackgroundColor: AppColors.border,
                        foregroundColor: AppColors.textOnAccent,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.full,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? AppColors.accentLight : AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppDuration.fast,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: checked ? AppColors.accent : AppColors.bgCard,
                  borderRadius: AppRadius.sm,
                  border: Border.all(
                    color: checked ? AppColors.accent : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: AppColors.textOnAccent,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: AppRadius.full,
      ),
    );
  }
}

({
  String title,
  String description,
  String confirmLabel,
  IconData icon,
  Color accent,
})
_config(DriverDeliveryAction action) {
  return switch (action) {
    DriverDeliveryAction.startPickupJourney => (
      title: 'Bắt đầu hành trình lấy hàng?',
      description:
          'Khách hàng sẽ được thông báo rằng bạn đang di chuyển đến điểm lấy.',
      confirmLabel: 'Bắt đầu hành trình',
      icon: Icons.navigation_rounded,
      accent: AppColors.accent,
    ),
    DriverDeliveryAction.confirmPickup => (
      title: 'Xác nhận đã nhận hàng',
      description:
          'Ảnh xác nhận sẽ được lưu. GPS chỉ chạy lại khi bạn bắt đầu giao.',
      confirmLabel: 'Đã nhận hàng',
      icon: Icons.inventory_2_rounded,
      accent: AppColors.markerPickup,
    ),
    DriverDeliveryAction.startDelivery => (
      title: 'Bắt đầu giao hàng?',
      description: 'Lộ trình sẽ chuyển sang địa chỉ người nhận.',
      confirmLabel: 'Bắt đầu giao',
      icon: Icons.local_shipping_rounded,
      accent: AppColors.accent,
    ),
    DriverDeliveryAction.confirmDelivery => (
      title: 'Hoàn tất đơn hàng?',
      description:
          'Hành động này xác nhận kiện hàng đã được bàn giao thành công.',
      confirmLabel: 'Hoàn tất giao hàng',
      icon: Icons.check_circle_rounded,
      accent: AppColors.success,
    ),
    DriverDeliveryAction.none => (
      title: 'Không có thao tác',
      description: 'Đơn hàng không có bước tiếp theo.',
      confirmLabel: 'Đóng',
      icon: Icons.info_outline_rounded,
      accent: AppColors.textMuted,
    ),
  };
}
