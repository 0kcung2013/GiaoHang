import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_theme.dart';

class CargoImagePicker extends StatefulWidget {
  const CargoImagePicker({
    super.key,
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  State<CargoImagePicker> createState() => _CargoImagePickerState();
}

class _CargoImagePickerState extends State<CargoImagePicker> {
  static const _debugTag = '[CargoImagePickerDebug]';

  Uint8List? _previewBytes;
  bool _isLoadingPreview = false;

  @override
  void initState() {
    super.initState();
    _loadPreview(widget.image);
  }

  @override
  void didUpdateWidget(CargoImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image?.path != widget.image?.path ||
        oldWidget.image?.name != widget.image?.name) {
      _loadPreview(widget.image);
    }
  }

  Future<void> _loadPreview(XFile? image) async {
    if (image == null) {
      setState(() {
        _previewBytes = null;
        _isLoadingPreview = false;
      });
      return;
    }

    setState(() => _isLoadingPreview = true);
    try {
      final bytes = await image.readAsBytes();
      debugPrint(
        '$_debugTag preview loaded name=${image.name} bytes=${bytes.length}',
      );
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _isLoadingPreview = false;
      });
    } catch (error) {
      debugPrint('$_debugTag preview load failed error=$error');
      if (!mounted) return;
      setState(() {
        _previewBytes = null;
        _isLoadingPreview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedImage = widget.image;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.md,
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildPreview(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedImage == null ? 'Ảnh hàng hoá' : selectedImage.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  selectedImage == null
                      ? 'Tải lên 1 ảnh JPEG, PNG hoặc WebP.'
                      : 'Ảnh sẽ được tải lên khi tạo đơn.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (selectedImage != null)
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.close_rounded),
              color: AppColors.error,
              tooltip: 'Xoá ảnh',
            )
          else
            TextButton.icon(
              onPressed: () {
                debugPrint('$_debugTag choose button tapped');
                widget.onPick();
              },
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Chọn ảnh'),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final bytes = _previewBytes;
    if (_isLoadingPreview) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }

    return const Icon(
      Icons.image_rounded,
      color: AppColors.textMuted,
      size: 22,
    );
  }
}
