import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:giaohang_design/giaohang_design.dart';

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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.accent,
              size: 26,
            ),
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
          Row(
            children: [
              if (showCamera) ...[
                Expanded(
                  child: _PhotoAction(
                    icon: Icons.photo_camera_outlined,
                    label: 'Chụp ảnh',
                    primary: true,
                    onTap: onPickCamera,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: _PhotoAction(
                  icon: Icons.photo_library_outlined,
                  label: showCamera ? 'Thư viện' : 'Chọn ảnh',
                  onTap: onPickGallery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.accent : AppColors.bgCard,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.full,
            border: primary ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: primary ? AppColors.textOnAccent : AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: primary ? AppColors.textOnAccent : AppColors.accent,
                    fontWeight: FontWeight.w800,
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
        color: AppColors.bgLight,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
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
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.accent,
                          size: 24,
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
                InkWell(
                  onTap: onReplace,
                  borderRadius: AppRadius.full,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.full,
                    ),
                    child: Text(
                      'Thay ảnh',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
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
