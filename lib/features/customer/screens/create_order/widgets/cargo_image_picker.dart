import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_theme.dart';

class CargoImagePicker extends StatefulWidget {
  const CargoImagePicker({
    super.key,
    required this.image,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  final XFile? image;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  @override
  State<CargoImagePicker> createState() => _CargoImagePickerState();
}

class _CargoImagePickerState extends State<CargoImagePicker> {
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
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _isLoadingPreview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewBytes = null;
        _isLoadingPreview = false;
      });
    }
  }

  void _previewImage() {
    final bytes = _previewBytes;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: AppRadius.lg,
              child: InteractiveViewer(child: Image.memory(bytes)),
            ),
            IconButton.filled(
              tooltip: 'Đóng xem ảnh',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final isWeb = kIsWeb;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDuration.normal;

    return AnimatedSize(
      duration: animationDuration,
      curve: AppCurve.standard,
      child: image == null
          ? _EmptyPhotoPicker(
              showCamera: !isWeb,
              onPickCamera: widget.onPickCamera,
              onPickGallery: widget.onPickGallery,
            )
          : _SelectedPhoto(
              imageName: image.name,
              bytes: _previewBytes,
              isLoading: _isLoadingPreview,
              onPreview: _previewImage,
              onReplace: widget.onPickGallery,
              onRemove: widget.onRemove,
            ),
    );
  }
}

class _EmptyPhotoPicker extends StatelessWidget {
  const _EmptyPhotoPicker({
    required this.showCamera,
    required this.onPickCamera,
    required this.onPickGallery,
  });

  final bool showCamera;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.xl,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_a_photo_outlined,
            color: AppColors.accent,
            size: 30,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Thêm ảnh kiện hàng',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tối đa 1 ảnh cho mỗi đơn hàng',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (showCamera) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onPickCamera,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                ),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Chụp ảnh'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              onPressed: onPickGallery,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(showCamera ? 'Chọn từ thư viện' : 'Chọn ảnh'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPhoto extends StatelessWidget {
  const _SelectedPhoto({
    required this.imageName,
    required this.bytes,
    required this.isLoading,
    required this.onPreview,
    required this.onReplace,
    required this.onRemove,
  });

  final String imageName;
  final Uint8List? bytes;
  final bool isLoading;
  final VoidCallback onPreview;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.xl,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Xem trước ảnh kiện hàng',
            child: InkWell(
              onTap: onPreview,
              borderRadius: AppRadius.md,
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: AppRadius.md,
                ),
                clipBehavior: Clip.antiAlias,
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : bytes == null
                    ? const Icon(Icons.image_not_supported_outlined)
                    : Image.memory(bytes!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 ảnh đã chọn',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  imageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onReplace,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  child: const Text('Thay ảnh'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Xoá ảnh',
            onPressed: onRemove,
            color: AppColors.error,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}
