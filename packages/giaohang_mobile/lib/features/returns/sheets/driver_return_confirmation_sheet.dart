import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../core/services/delivery_proof_watermark_service.dart';
import '../../driver/screens/navigation/widgets/driver_proof_photo_field.dart';

class DriverReturnConfirmationResult {
  const DriverReturnConfirmationResult({
    required this.receiverName,
    required this.proof,
    this.note,
  });

  final String receiverName;
  final DeliveryProofCapture proof;
  final String? note;
}

Future<DriverReturnConfirmationResult?> showDriverReturnConfirmationSheet(
  BuildContext context, {
  required DeliveryProofLocationProvider locationProvider,
}) {
  return showModalBottomSheet<DriverReturnConfirmationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _DriverReturnConfirmationSheet(locationProvider: locationProvider),
  );
}

class _DriverReturnConfirmationSheet extends StatefulWidget {
  const _DriverReturnConfirmationSheet({required this.locationProvider});

  final DeliveryProofLocationProvider locationProvider;

  @override
  State<_DriverReturnConfirmationSheet> createState() =>
      _DriverReturnConfirmationSheetState();
}

class _DriverReturnConfirmationSheetState
    extends State<_DriverReturnConfirmationSheet> {
  final _receiverController = TextEditingController();
  final _noteController = TextEditingController();
  DeliveryProofCapture? _proof;
  bool _checked = false;
  String? _error;

  @override
  void dispose() {
    _receiverController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadow.elevated,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.full,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Xác nhận đã hoàn hàng', style: AppTextStyles.headingMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chụp rõ kiện hàng tại điểm trả và ghi tên người tiếp nhận.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const Key('return-receiver-name'),
                controller: _receiverController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Người tiếp nhận',
                  hintText: 'Ví dụ: Nguyễn Văn An',
                  border: OutlineInputBorder(borderRadius: AppRadius.md),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              DriverProofPhotoField(
                accent: AppColors.warning,
                locationProvider: widget.locationProvider,
                onChanged: (proof) => setState(() => _proof = proof),
              ),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                value: _checked,
                onChanged: (value) => setState(() => _checked = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Kiện hàng đã được bên nhận kiểm tra và tiếp nhận',
                ),
              ),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                  border: OutlineInputBorder(borderRadius: AppRadius.md),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                key: const Key('confirm-order-return'),
                onPressed: _submit,
                icon: const Icon(Icons.inventory_2_rounded),
                label: const Text('Xác nhận hoàn tất'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                  textStyle: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.full,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final receiver = _receiverController.text.trim();
    if (receiver.length < 2 || _proof == null || !_checked) {
      setState(
        () => _error = 'Nhập người nhận, chụp ảnh và xác nhận bàn giao.',
      );
      return;
    }
    Navigator.pop(
      context,
      DriverReturnConfirmationResult(
        receiverName: receiver,
        proof: _proof!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }
}
