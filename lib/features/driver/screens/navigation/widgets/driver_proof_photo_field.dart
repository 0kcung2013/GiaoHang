import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_theme.dart';

typedef CaptureProofPhoto = Future<XFile?> Function();

class DriverProofPhotoField extends StatefulWidget {
  const DriverProofPhotoField({
    super.key,
    required this.accent,
    required this.onChanged,
    this.capturePhoto,
  });

  final Color accent;
  final ValueChanged<XFile?> onChanged;
  final CaptureProofPhoto? capturePhoto;

  @override
  State<DriverProofPhotoField> createState() => _DriverProofPhotoFieldState();
}

class _DriverProofPhotoFieldState extends State<DriverProofPhotoField> {
  Uint8List? _previewBytes;
  bool _isCapturing = false;

  Future<void> _capture() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final photo =
          await widget.capturePhoto?.call() ??
          await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 82,
            maxWidth: 1600,
            requestFullMetadata: false,
          );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() => _previewBytes = bytes);
      widget.onChanged(photo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể mở máy ảnh. Vui lòng kiểm tra quyền camera.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _previewBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ẢNH XÁC NHẬN BẮT BUỘC',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (hasPhoto)
              const Icon(
                Icons.verified_rounded,
                size: 18,
                color: AppColors.success,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: AppColors.bgLight,
          borderRadius: AppRadius.lg,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _capture,
            child: AnimatedContainer(
              duration: AppDuration.normal,
              width: double.infinity,
              height: 168,
              decoration: BoxDecoration(
                borderRadius: AppRadius.lg,
                border: Border.all(
                  color: hasPhoto ? AppColors.success : widget.accent,
                  width: hasPhoto ? 2 : 1.5,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPhoto)
                    Image.memory(_previewBytes!, fit: BoxFit.cover)
                  else
                    _EmptyPhotoState(
                      accent: widget.accent,
                      isCapturing: _isCapturing,
                    ),
                  if (hasPhoto)
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.88),
                          borderRadius: AppRadius.full,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.textOnDark,
                              size: 17,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Chụp lại',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textOnDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Ảnh được lưu riêng tư và gắn với đơn hàng này.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _EmptyPhotoState extends StatelessWidget {
  const _EmptyPhotoState({required this.accent, required this.isCapturing});

  final Color accent;
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCapturing
                  ? Icons.hourglass_top_rounded
                  : Icons.camera_alt_rounded,
              color: accent,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isCapturing ? 'Đang mở máy ảnh...' : 'Chạm để chụp ảnh',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chụp rõ kiện hàng và bối cảnh bàn giao',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
