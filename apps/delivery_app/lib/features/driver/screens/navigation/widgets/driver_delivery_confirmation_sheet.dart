import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/services/delivery_proof_watermark_service.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../models/driver_delivery_workflow.dart';
import 'driver_proof_photo_field.dart';

class DriverDeliveryConfirmationResult {
  const DriverDeliveryConfirmationResult({this.proof});

  final DeliveryProofCapture? proof;
}

Future<DriverDeliveryConfirmationResult?> showDriverDeliveryConfirmationSheet({
  required BuildContext context,
  required DriverDeliveryAction action,
  required OrderModel order,
  required DeliveryProofLocationProvider locationProvider,
  CaptureProofPhoto? capturePhoto,
  DeliveryProofAddressResolver? resolveAddress,
  DeliveryProofWatermarker? watermarkPhoto,
}) async {
  return showModalBottomSheet<DriverDeliveryConfirmationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DriverDeliveryConfirmationSheet(
      action: action,
      order: order,
      locationProvider: locationProvider,
      capturePhoto: capturePhoto,
      resolveAddress: resolveAddress,
      watermarkPhoto: watermarkPhoto,
    ),
  );
}

class _DriverDeliveryConfirmationSheet extends StatefulWidget {
  const _DriverDeliveryConfirmationSheet({
    required this.action,
    required this.order,
    required this.locationProvider,
    this.capturePhoto,
    this.resolveAddress,
    this.watermarkPhoto,
  });

  final DriverDeliveryAction action;
  final OrderModel order;
  final DeliveryProofLocationProvider locationProvider;
  final CaptureProofPhoto? capturePhoto;
  final DeliveryProofAddressResolver? resolveAddress;
  final DeliveryProofWatermarker? watermarkPhoto;

  @override
  State<_DriverDeliveryConfirmationSheet> createState() =>
      _DriverDeliveryConfirmationSheetState();
}

class _DriverDeliveryConfirmationSheetState
    extends State<_DriverDeliveryConfirmationSheet> {
  final Set<int> _checkedItems = {};
  DeliveryProofCapture? _proof;

  bool get _requiresPhoto => widget.action.requiresProofPhoto;

  List<String> get _checklist {
    return switch (widget.action) {
      DriverDeliveryAction.startPickupJourney => const [],
      DriverDeliveryAction.confirmPickup => [
        'Đã nhận đúng kiện hàng của đơn này',
        'Đã kiểm tra tình trạng bên ngoài của kiện hàng',
      ],
      DriverDeliveryAction.startDelivery => const [],
      DriverDeliveryAction.confirmDelivery => [
        'Đã giao đúng người nhận hoặc người được ủy quyền',
        'Đã thu ${formatVnd(widget.order.receiverCollectionAmount)} từ người nhận',
      ],
      DriverDeliveryAction.none => const [],
    };
  }

  bool get _canConfirm {
    final checklistComplete =
        _checklist.isEmpty || _checkedItems.length == _checklist.length;
    return checklistComplete && (!_requiresPhoto || _proof != null);
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
                  locationProvider: widget.locationProvider,
                  capturePhoto: widget.capturePhoto,
                  resolveAddress: widget.resolveAddress,
                  watermarkPhoto: widget.watermarkPhoto,
                  onChanged: (proof) => setState(() => _proof = proof),
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
                        textStyle: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                              DriverDeliveryConfirmationResult(proof: _proof),
                            )
                          : null,
                      icon: Icon(config.icon, size: 19),
                      label: Text(config.confirmLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: config.accent,
                        disabledBackgroundColor: AppColors.border,
                        foregroundColor: AppColors.textOnAccent,
                        minimumSize: const Size.fromHeight(52),
                        textStyle: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
