import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:image_picker/image_picker.dart';
import '../driver_auth_strings.dart';
import 'driver_auth_feedback.dart';

/// Preview local selections only; uploads remain owned by the wizard submit flow.
class DriverDocumentPicker extends StatefulWidget {
  const DriverDocumentPicker({
    super.key,
    required this.label,
    required this.icon,
    required this.file,
    required this.onTap,
    this.hint,
    this.error,
    this.portrait = false,
  });
  final String label;
  final IconData icon;
  final XFile? file;
  final VoidCallback? onTap;
  final String? hint;
  final String? error;
  final bool portrait;

  @override
  State<DriverDocumentPicker> createState() => _DriverDocumentPickerState();
}

class _DriverDocumentPickerState extends State<DriverDocumentPicker> {
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.file?.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant DriverDocumentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) _bytes = widget.file?.readAsBytes();
    if (widget.error != null && oldWidget.error != widget.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scrollable.ensureVisible(context, alignment: 0.2);
      });
    }
  }

  Widget _preview() => SizedBox.square(
    dimension: widget.portrait ? 64 : 56,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.sm,
      ),
      child: _bytes == null
          ? Icon(widget.icon, size: 24, color: AppColors.textSecondary)
          : FutureBuilder<Uint8List>(
              future: _bytes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.error,
                    semanticLabel: DriverAuthStrings.previewError,
                  );
                }
                if (!snapshot.hasData) {
                  return Icon(
                    widget.icon,
                    size: 24,
                    color: AppColors.textSecondary,
                  );
                }
                return ClipRRect(
                  borderRadius: AppRadius.sm,
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    cacheWidth: 320,
                    semanticLabel: widget.label,
                    errorBuilder: (_, error, stack) => const Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.error,
                      semanticLabel: DriverAuthStrings.previewError,
                    ),
                  ),
                );
              },
            ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        button: true,
        label: widget.label,
        value: widget.file == null
            ? DriverAuthStrings.pickPhoto
            : DriverAuthStrings.selectedPhoto,
        child: Material(
          color: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.md,
            side: BorderSide(
              color: widget.error == null ? AppColors.border : AppColors.error,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _preview(),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.label,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.hint != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.hint!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.file == null
                              ? DriverAuthStrings.pickPhoto
                              : DriverAuthStrings.changePhoto,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.file != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      if (widget.error != null) ...[
        const SizedBox(height: AppSpacing.sm),
        DriverAuthNotice(message: widget.error!, error: true),
      ],
    ],
  );
}
